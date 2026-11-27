import Foundation
import Observation
import OSLog

// Owns the one job: the answer that asked for it may end or be stopped while the job goes on.
@Observable
final class Jobs {
    private(set) var shown: Job?
    @ObservationIgnored private let runner: ClaudeJobRunner
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    @ObservationIgnored private var isStarting = false
    @ObservationIgnored private var process: JobProcess?
    @ObservationIgnored private var following: Task<Void, Never>?

    init(runner: ClaudeJobRunner) {
        self.runner = runner
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
        let lines: AsyncLineSequence<FileHandle.AsyncBytes>
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

    private func follow(_ lines: AsyncLineSequence<FileHandle.AsyncBytes>, of process: JobProcess, jobID: UUID) async {
        var ending = JobEnding()
        do {
            for try await line in lines {
                guard !Task.isCancelled else { return }
                read(JobStreamEvent(line: line), of: process, jobID: jobID, ending: &ending)
            }
        } catch is CancellationError {
            return
        } catch {
            logger.error("The job's output could not be read: \((error as NSError).code, privacy: .public)")
        }
        logger.notice("The job's output ended")
        if let result = ending.result {
            let hasReport = await Self.logFolder(runner.workFolder(jobID: jobID), logger: logger)
            end(jobID, as: hasReport ? .done(result: result) : .failed(.noReport))
        }
        end(jobID, as: .failed(ending.failure ?? .endedEarly))
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

    // The report is written before the result, so it is there once the output has ended.
    private static func logFolder(_ folder: URL, logger: Logger) async -> Bool {
        do {
            let files = try await ClaudeJobRunner.files(in: folder)
            let hasReport = files.contains(JobInstructions.reportName)
            logger.notice("The job's folder holds \(files.count, privacy: .public) files")
            logger.notice("The job's folder holds report.md: \(hasReport, privacy: .public)")
            return hasReport
        } catch {
            logger.error("The job's folder could not be listed: \((error as NSError).code, privacy: .public)")
            return false
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
