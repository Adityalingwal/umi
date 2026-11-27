import Foundation
import OSLog

// Jobs run on Claude whichever brain answers, so this checks and starts Claude itself, never the chosen brain.
struct ClaudeJobRunner {
    private let executable: ClaudeExecutable
    private let environment: [String: String]
    private let jobsFolder: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")

    init(executable: ClaudeExecutable, environment: [String: String], jobsFolder: URL) {
        self.executable = executable
        self.environment = environment
        self.jobsFolder = jobsFolder
    }

    // The login is checked the way the job will run; a check that cannot answer starts no job.
    func refusal() async -> JobStart.Refusal? {
        guard let executableURL = executable.locate(environment: environment) else { return .claudeNotInstalled }
        do {
            let output = try await StatusCommand(
                executableURL: executableURL,
                arguments: ["auth", "status", "--json"],
                environment: JobLaunch.environment(from: environment)
            ).run()
            let isSubscription = JobLogin.isSubscription(statusOutput: output.standardOutput)
            logger.notice("The job's Claude login is a Claude subscription: \(isSubscription, privacy: .public)")
            return isSubscription ? nil : .claudeNotSignedIn
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("The job's Claude login could not be checked, so no job starts")
            return .claudeNotSignedIn
        }
    }

    func launch(jobID: UUID) async throws -> JobLaunch {
        guard let executableURL = executable.locate(environment: environment) else {
            throw BrainError.notInstalled(.claude)
        }
        let workFolder = workFolder(jobID: jobID)
        try await Self.makeFolder(workFolder)
        return JobLaunch(
            executableURL: executableURL,
            workFolder: workFolder,
            jobID: jobID,
            appEnvironment: environment
        )
    }

    func workFolder(jobID: UUID) -> URL {
        jobsFolder.appending(path: jobID.uuidString).appending(path: "work")
    }

    // A job stopped before its process ran leaves no empty folder behind.
    func removeFolder(jobID: UUID) async throws {
        try await Self.remove(jobsFolder.appending(path: jobID.uuidString))
    }

    @concurrent
    static func files(in folder: URL) async throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
    }

    @concurrent
    private static func makeFolder(_ folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @concurrent
    private static func remove(_ folder: URL) async throws {
        try FileManager.default.removeItem(at: folder)
    }
}
