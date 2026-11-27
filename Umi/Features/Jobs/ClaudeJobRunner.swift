import Foundation

// Jobs run on Claude whichever brain answers, so this checks and starts Claude itself, never the chosen brain.
struct ClaudeJobRunner {
    private let executable: ClaudeExecutable
    private let check: BrainCheck
    private let environment: [String: String]
    private let jobsFolder: URL

    init(executable: ClaudeExecutable, check: BrainCheck, environment: [String: String], jobsFolder: URL) {
        self.executable = executable
        self.check = check
        self.environment = environment
        self.jobsFolder = jobsFolder
    }

    // A check that could not finish lets the job start; a sign-in problem then shows on its card.
    func refusal() async -> JobStart.Refusal? {
        guard executable.locate(environment: environment) != nil else { return .claudeNotInstalled }
        switch await check.availability(of: .claude) {
        case .notInstalled: return .claudeNotInstalled
        case .notSignedIn: return .claudeNotSignedIn
        case .usable, nil: return nil
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

    @concurrent
    private static func makeFolder(_ folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func workFolder(jobID: UUID) -> URL {
        jobsFolder.appending(path: jobID.uuidString).appending(path: "work")
    }

    @concurrent
    static func files(in folder: URL) async throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
    }
}
