import Foundation
import Observation
import OSLog

// Owns the one job: the answer that asked for it may end or be stopped while the job goes on.
@Observable
final class Jobs {
    private(set) var shown: Job?
    @ObservationIgnored let endings: AsyncStream<Job>
    @ObservationIgnored private let endingContinuation: AsyncStream<Job>.Continuation
    @ObservationIgnored private let runner: ClaudeJobRunner
    @ObservationIgnored private let opener: JobFileOpener
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var process: JobProcess?
    @ObservationIgnored private var following: Task<Void, Never>?

    init(runner: ClaudeJobRunner, opener: JobFileOpener) {
        self.runner = runner
        self.opener = opener
        (endings, endingContinuation) = AsyncStream.makeStream(of: Job.self)
    }

    var isWorking: Bool {
        shown?.isWorking == true
    }

    var brief: String? {
        shown.map(JobBrief.text(for:))
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

    // The folder is read again each time, so a file added or removed since the job ended is shown as it is now.
    func refreshFiles() async {
        guard let job = shown, !job.isWorking else { return }
        setFiles(await files(of: job.id), jobID: job.id)
    }

    func open(_ file: JobFile) async {
        guard let job = shown else { return }
        await opener.open(runner.workFolder(jobID: job.id).appending(path: file.name))
    }

    func report() async -> JobReport? {
        guard let job = shown, case .done = job.state else { return nil }
        do {
            let report = try await runner.report(jobID: job.id)
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
        guard let process, process.isRunning else { return }
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
        log(launch, processID: process.processID, jobID: id)
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
        shown = Job(id: id, name: request.name, task: request.task)
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

    private func log(_ launch: JobLaunch, processID: Int32, jobID: UUID) {
        logger.notice("Started a job on Claude, process \(processID, privacy: .public)")
        logger.notice("The job works in Umi's folder: Jobs/\(jobID.uuidString, privacy: .public)/work")
        logger.notice("The job's switches: <claude> \(launch.loggedArguments, privacy: .public)")
        let added = JobLaunch.addedVariables.keys.filter { launch.environment[$0] != nil }.sorted()
        let hasOverride = launch.environment.keys.contains(where: JobLaunch.isProviderOverride)
        logger.notice("The job's environment adds \(added.joined(separator: ", "), privacy: .public)")
        logger.notice("The job's environment holds a key, server or provider: \(hasOverride, privacy: .public)")
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
        let files = await files(of: jobID)
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
            logger.notice("The job's Claude started: model \(model, privacy: .public)")
            logger.notice("The job's Claude key source: \(apiKeySource, privacy: .public)")
            logger.notice("The job's tools: \(Self.loggedNames(tools), privacy: .public)")
        case let .toolCalls(names, checklist):
            logger.notice("The job called \(Self.loggedNames(names), privacy: .public)")
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
            logRefused(refusedTools)
            ending.result = Self.oneLine(result)
            process.endInput()
        case .failed(let refusedTools):
            logRefused(refusedTools)
            end(jobID, as: .failed(ending.failure ?? .claudeError))
            process.endInput()
        case .other:
            break
        }
    }

    private func updateSteps(_ steps: [JobStep], jobID: UUID) {
        guard var job = shown, job.id == jobID, job.isWorking else { return }
        job.steps = steps
        shown = job
        let done = job.doneCount
        logger.notice("The job's checklist: \(done, privacy: .public) of \(steps.count, privacy: .public) steps done")
    }

    private func end(_ jobID: UUID, as state: Job.State) {
        guard var job = shown, job.id == jobID, job.isWorking else { return }
        job.state = state
        shown = job
        switch state {
        case .working:
            return
        case .done:
            logger.notice("The job is done")
        case .failed(let failure):
            logger.error("The job did not finish: \(String(describing: failure), privacy: .public)")
        }
        endingContinuation.yield(job)
    }

    private func logRefused(_ tools: [String]) {
        let count = tools.count
        let names = Self.loggedNames(tools)
        logger.notice("The job's Claude refused \(count, privacy: .public) tool calls: \(names, privacy: .public)")
    }

    // A tool name comes from the job's process, so only the names Umi gave the job are written as they are.
    private static func loggedNames(_ names: [String]) -> String {
        names.map { JobLaunch.tools.contains($0) ? $0 : "other" }.joined(separator: ", ")
    }

    private func setFiles(_ files: [JobFile], jobID: UUID) {
        guard var job = shown, job.id == jobID, !job.isWorking, job.files != files else { return }
        job.files = files
        shown = job
    }

    private func files(of jobID: UUID) async -> [JobFile] {
        do {
            let files = try await runner.files(jobID: jobID)
            let documents = files.count { $0.kind == .document }
            let count = files.count
            logger.notice("The job's folder holds \(count, privacy: .public) files")
            logger.notice("The job's folder holds \(documents, privacy: .public) documents")
            return files
        } catch {
            logger.error("The job's folder could not be listed: \((error as NSError).code, privacy: .public)")
            return []
        }
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
