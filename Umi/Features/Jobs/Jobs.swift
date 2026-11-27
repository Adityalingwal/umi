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
        let process = JobProcess(launch: launch)
        let lines: AsyncLineSequence<FileHandle.AsyncBytes>
        do {
            lines = try await process.start(task: request.task)
        } catch {
            process.stop()
            logger.error("No job started: Claude could not be started (\((error as NSError).code, privacy: .public))")
            return .refused(.couldNotStart)
        }
        log(launch, processID: process.processID, jobID: id)
        self.process = process
        shown = Job(id: id, name: request.name, task: request.task)
        following = Task { [weak self] in
            await self?.follow(lines, of: process, jobID: id)
        }
        return .started(request)
    }

    private func log(_ launch: JobLaunch, processID: Int32, jobID: UUID) {
        logger.notice("Started a job on Claude, process \(processID, privacy: .public)")
        logger.notice("The job works in Umi's folder: Jobs/\(jobID.uuidString, privacy: .public)/work")
        logger.notice("The job's switches: <claude> \(launch.loggedArguments, privacy: .public)")
        let added = JobLaunch.addedVariables.keys.filter { launch.environment[$0] != nil }.sorted()
        let hasKey = launch.environment.keys.contains { $0.hasPrefix("ANTHROPIC_") }
        logger.notice("The job's environment adds \(added.joined(separator: ", "), privacy: .public)")
        logger.notice("The job's environment holds ANTHROPIC_ variables: \(hasKey, privacy: .public)")
    }

    private func follow(_ lines: AsyncLineSequence<FileHandle.AsyncBytes>, of process: JobProcess, jobID: UUID) async {
        var failure: JobFailure?
        do {
            for try await line in lines {
                guard !Task.isCancelled else { return }
                read(JobStreamEvent(line: line), of: process, jobID: jobID, failure: &failure)
            }
        } catch is CancellationError {
            return
        } catch {
            logger.error("The job's output could not be read: \((error as NSError).code, privacy: .public)")
        }
        logger.notice("The job's output ended")
        end(jobID, as: .failed(failure ?? .endedEarly))
        if case .done = shown?.state, shown?.id == jobID {
            await Self.logFolder(runner.workFolder(jobID: jobID), logger: logger)
        }
        if self.process === process {
            self.process = nil
        }
    }

    private func read(_ event: JobStreamEvent, of process: JobProcess, jobID: UUID, failure: inout JobFailure?) {
        switch event {
        case let .started(model, apiKeySource, tools):
            logger.notice("The job's Claude started: model \(model, privacy: .public)")
            logger.notice("The job's Claude key source: \(apiKeySource, privacy: .public)")
            logger.notice("The job's tools: \(tools.joined(separator: ", "), privacy: .public)")
        case let .toolCalls(names, checklist):
            logger.notice("The job called \(names.joined(separator: ", "), privacy: .public)")
            if let checklist {
                updateSteps(JobStep.steps(inChecklist: checklist), jobID: jobID)
            }
        case .apiError(let error):
            logger.error("The job's Claude reported an error: \(String(describing: error), privacy: .public)")
            failure = error
        case .connectionLost:
            logger.error("The job's Claude could not reach its server, so the job stops")
            end(jobID, as: .failed(.noInternet))
            process.stop()
        case let .finished(result, refusedTools):
            logRefused(refusedTools)
            end(jobID, as: .done(result: Self.oneLine(result)))
            process.endInput()
        case .failed(let refusedTools):
            logRefused(refusedTools)
            end(jobID, as: .failed(failure ?? .claudeError))
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
        let names = tools.joined(separator: ", ")
        let count = tools.count
        logger.notice("The job's Claude refused \(count, privacy: .public) tool calls: \(names, privacy: .public)")
    }

    private static func logFolder(_ folder: URL, logger: Logger) async {
        do {
            let files = try await ClaudeJobRunner.files(in: folder)
            let hasReport = files.contains(JobInstructions.reportName)
            logger.notice("The job's folder holds \(files.count, privacy: .public) files")
            logger.notice("The job's folder holds report.md: \(hasReport, privacy: .public)")
        } catch {
            logger.error("The job's folder could not be listed: \((error as NSError).code, privacy: .public)")
        }
    }

    // The job ends with a sentence for the voice; any text before it is not that line.
    private static func oneLine(_ result: String) -> String {
        let lines = result.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.last { !$0.isEmpty } ?? "The report is in the job's folder."
    }
}
