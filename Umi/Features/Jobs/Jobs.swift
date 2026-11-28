import Foundation
import Observation
import OSLog

// Owns the jobs, saved ones included: the answer that asked for one may end or be stopped while the job goes on.
@Observable
final class Jobs {
    // Newest first; only the newest can be working.
    private(set) var all: [Job] = []
    @ObservationIgnored let endings: AsyncStream<Job>
    @ObservationIgnored private let endingContinuation: AsyncStream<Job>.Continuation
    @ObservationIgnored private let runner: ClaudeJobRunner
    @ObservationIgnored private let opener: JobFileOpener
    @ObservationIgnored private let savedJobs: SavedJobs
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    @ObservationIgnored private let log = JobLog()
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var hasStartedAJob = false
    @ObservationIgnored private var process: JobProcess?
    @ObservationIgnored private var following: Task<Void, Never>?

    init(runner: ClaudeJobRunner, opener: JobFileOpener, records: JobRecords) {
        self.runner = runner
        self.opener = opener
        savedJobs = SavedJobs(records: records)
        (endings, endingContinuation) = AsyncStream.makeStream(of: Job.self)
    }

    // The running job, or the last one until a new one starts.
    var shown: Job? {
        all.first
    }

    var isWorking: Bool {
        shown?.isWorking == true
    }

    func job(_ jobID: UUID) -> Job? {
        all.first { $0.id == jobID }
    }

    // Saved jobs are never sent anywhere, so only a job started since Umi opened goes to the brain.
    var brief: String? {
        hasStartedAJob ? shown.map(JobBrief.text(for:)) : nil
    }

    // Runs once, before any question is taken, so the saved jobs are older than any job started after it.
    func load() async {
        all.append(contentsOf: await savedJobs.read())
    }

    func saved() async {
        await savedJobs.written()
    }

    func start(_ request: JobRequest) async -> JobStart {
        let name = request.name.count
        let task = request.task.count
        logger.notice("A job was asked for: a name of \(name, privacy: .public) characters")
        logger.notice("The job's task has \(task, privacy: .public) characters")
        guard !isWorking, !isStarting else {
            logger.notice("No job started: a job is running")
            return .refused(.jobRunning)
        }
        isStarting = true
        defer { isStarting = false }
        if let refusal = await runner.refusal() {
            logger.notice("No job started: \(String(describing: refusal), privacy: .public)")
            return .refused(refusal)
        }
        guard !Task.isCancelled else {
            logger.notice("No job started: the question was stopped")
            return .cancelled
        }
        return await launch(request)
    }

    // The job ends at once: its card says it was stopped and the notch is plain, with no banner and no spoken line.
    // Its process ends after it, and what it made is listed once its output is over.
    @discardableResult
    func stop(_ jobID: UUID? = nil) -> Bool {
        guard let job = working(jobID), let process else {
            logger.notice("Stop: no job is running")
            return false
        }
        update(job.id) { $0.end(as: .stopped) }
        process.stop()
        logger.notice("The job was stopped: its process \(process.processID, privacy: .public) was ended")
        logger.notice("The job's process group was signalled: \(process.hasOwnProcessGroup, privacy: .public)")
        return true
    }

    func send(_ message: String, to jobID: UUID? = nil) async -> JobAsk.Outcome {
        guard let job = working(jobID), let process, process.canTakeMessages else {
            logger.notice("A message for the job was not passed on: no job is running")
            return .noJobRunning
        }
        do {
            try await process.send(message: message)
        } catch is CancellationError {
            logger.notice("A message for the job was not sent: the question was stopped")
            return .cancelled
        } catch {
            logger.error("A message for the job could not be passed on (\((error as NSError).code, privacy: .public))")
            return .notDelivered
        }
        logger.notice("A message was passed to the job: \(message.count, privacy: .public) characters")
        update(job.id) { $0.messages.append(message) }
        return .done
    }

    // The folder is read again each time, so a file added or removed since the job ended is shown as it is now.
    func refreshFiles(of jobID: UUID) async {
        guard let job = job(jobID), !job.isWorking else { return }
        setFiles(await runner.listedFiles(jobID: jobID), jobID: jobID)
    }

    // The file is looked for in the folder of the job whose card or page shows it, never another job's.
    func open(_ file: JobFile, of jobID: UUID) async {
        guard job(jobID) != nil else { return }
        await opener.open(runner.workFolder(jobID: jobID).appending(path: file.name))
    }

    func report(of jobID: UUID) async -> JobReport? {
        guard let job = job(jobID), case .done = job.state else { return nil }
        do {
            let report = try await runner.report(jobID: jobID)
            logger.notice("The job's report was read: \(report.blocks.count, privacy: .public) blocks")
            return report
        } catch {
            logger.error("The job's report could not be read: \((error as NSError).code, privacy: .public)")
            return nil
        }
    }

    // At quit the job's process is ended, so no job outlives Umi.
    func stopAtQuit() {
        following?.cancel()
        guard let process else { return }
        let processID = process.processID
        process.stop()
        logger.notice("Umi quits: the job's process \(processID, privacy: .public) was ended")
    }

    private func launch(_ request: JobRequest) async -> JobStart {
        let id = UUID()
        let launch: JobLaunch
        do {
            launch = try await runner.launch(jobID: id)
        } catch {
            logger.error("No job started: its folder could not be made (\((error as NSError).code, privacy: .public))")
            return .refused(.couldNotStart)
        }
        guard !Task.isCancelled else {
            logger.notice("No job started: the question was stopped while its folder was made")
            await removeFolder(jobID: id)
            return .cancelled
        }
        let process = JobProcess(launch: launch)
        do {
            try process.run()
        } catch {
            logger.error("No job started: Claude could not be started (\((error as NSError).code, privacy: .public))")
            await removeFolder(jobID: id)
            return .refused(.couldNotStart)
        }
        self.process = process
        log.started(launch, process: process, jobID: id)
        let lines: AsyncStream<String>
        do {
            lines = try await process.send(task: request.task)
        } catch {
            process.stop()
            if self.process === process {
                self.process = nil
            }
            logger.error("No job started: the task could not be sent (\((error as NSError).code, privacy: .public))")
            return .refused(.couldNotStart)
        }
        all.insert(Job(id: id, name: request.name, task: request.task, startedAt: .now), at: 0)
        hasStartedAJob = true
        savedJobs.save(all[0])
        following = Task { [weak self] in
            await self?.follow(lines, of: process, jobID: id)
        }
        return .started(request)
    }

    private func removeFolder(jobID: UUID) async {
        do {
            try await runner.removeFolder(jobID: jobID)
        } catch {
            logger.error("The unused job folder could not be removed: \((error as NSError).code, privacy: .public)")
        }
    }

    private func follow(_ lines: AsyncStream<String>, of process: JobProcess, jobID: UUID) async {
        var ending = JobEnding()
        for await line in lines {
            guard !Task.isCancelled else { return }
            read(JobStreamEvent(line: line), of: process, jobID: jobID, ending: &ending)
        }
        guard !Task.isCancelled else { return }
        logger.notice("The job's output ended")
        // The report is written before the result, so it is there once the output has ended.
        let files = await runner.listedFiles(jobID: jobID)
        if let result = ending.result {
            let hasReport = files.contains { $0.name == JobInstructions.reportName && $0.kind == .document }
            logger.notice("The job's folder holds report.md: \(hasReport, privacy: .public)")
            end(jobID, as: hasReport ? .done(result: result) : .failed(.noReport))
        }
        end(jobID, as: .failed(ending.failure ?? .endedEarly))
        setFiles(files, jobID: jobID)
        if self.process === process {
            self.process = nil
        }
    }

    private func read(_ event: JobStreamEvent, of process: JobProcess, jobID: UUID, ending: inout JobEnding) {
        switch event {
        case let .started(model, apiKeySource, tools):
            log.claudeStarted(model: model, apiKeySource: apiKeySource, tools: tools)
        case let .toolCalls(names, checklist):
            log.called(names)
            if let checklist {
                updateSteps(JobStep.steps(inChecklist: checklist), jobID: jobID)
            }
        case .apiError(let error):
            logger.error("The job's Claude reported an error: \(String(describing: error), privacy: .public)")
            ending.failure = error
        case .connectionLost:
            logger.error("The job's Claude could not reach its server, so the job stops")
            end(jobID, as: .failed(.noInternet))
            process.stop()
        case let .finished(result, refusedTools):
            log.refused(refusedTools)
            ending.result = Self.oneLine(result)
            process.endInput()
        case .failed(let refusedTools):
            log.refused(refusedTools)
            end(jobID, as: .failed(ending.failure ?? .claudeError))
            process.endInput()
        case .other:
            break
        }
    }

    private func updateSteps(_ steps: [JobStep], jobID: UUID) {
        guard let job = job(jobID), job.isWorking else { return }
        update(jobID) { $0.steps = steps }
        let done = steps.count { $0.isDone }
        logger.notice("The job's checklist: \(done, privacy: .public) of \(steps.count, privacy: .public) steps done")
    }

    private func end(_ jobID: UUID, as state: Job.State) {
        guard var job = job(jobID), job.isWorking else { return }
        job.end(as: state)
        update(jobID) { [job] in $0 = job }
        switch state {
        case .working, .stopped:
            return
        case .done:
            logger.notice("The job is done")
        case .failed(let failure):
            logger.error("The job did not finish: \(String(describing: failure), privacy: .public)")
        }
        endingContinuation.yield(job)
    }

    private func setFiles(_ files: [JobFile], jobID: UUID) {
        guard let job = job(jobID), !job.isWorking, job.files != files else { return }
        update(jobID) { $0.files = files }
    }

    // A job's own page names its job, so its Stop or message never reaches another one; the brain names none.
    private func working(_ jobID: UUID?) -> Job? {
        guard let job = shown, job.isWorking, jobID == nil || jobID == job.id else { return nil }
        return job
    }

    private func update(_ jobID: UUID, _ change: (inout Job) -> Void) {
        guard let index = all.firstIndex(where: { $0.id == jobID }) else { return }
        change(&all[index])
        savedJobs.save(all[index])
    }

    // The job ends with a sentence for the voice; any text before it is not that line.
    private static func oneLine(_ result: String) -> String {
        let lines = result.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.last { !$0.isEmpty } ?? "The report is in the job's folder."
    }
}

// What the job's stream said about how it ended, read once its output is over.
private struct JobEnding {
    var failure: JobFailure?
    var result: String?
}
