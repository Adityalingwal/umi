import Foundation
import OSLog

struct BrainCheck {
    private let claudeExecutable: ClaudeExecutable
    private let codexExecutable: CodexExecutable
    private let codexFolders: CodexFolders
    private let environment: [String: String]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")

    init(
        claudeExecutable: ClaudeExecutable,
        codexExecutable: CodexExecutable,
        codexFolders: CodexFolders,
        environment: [String: String]
    ) {
        self.claudeExecutable = claudeExecutable
        self.codexExecutable = codexExecutable
        self.codexFolders = codexFolders
        self.environment = environment
    }

    // A check that could not finish gives no answer, so the menu keeps what it showed before.
    func availability(of brain: BrainKind) async -> BrainAvailability? {
        do {
            switch brain {
            case .claude: return try await claudeAvailability()
            case .codex: return try await codexAvailability()
            }
        } catch is CancellationError {
            return nil
        } catch {
            let reason = String(describing: error)
            logger.error("The \(brain.title, privacy: .public) check did not finish: \(reason, privacy: .public)")
            return nil
        }
    }

    private func claudeAvailability() async throws -> BrainAvailability {
        guard let executableURL = claudeExecutable.locate(environment: environment) else { return .notInstalled }
        let output = try await StatusCommand(
            executableURL: executableURL,
            arguments: ["auth", "status", "--json"],
            environment: ClaudeSubscription.childEnvironment(from: environment)
        ).run()
        return ClaudeAuthStatus.availability(statusOutput: output.standardOutput)
    }

    // The status runs in the user's own Codex home, with their own credential store, minus the key variables.
    private func codexAvailability() async throws -> BrainAvailability {
        guard let executableURL = codexExecutable.locate(environment: environment) else { return .notInstalled }
        let output = try await StatusCommand(
            executableURL: executableURL,
            arguments: ["login", "status"],
            environment: CodexSubscription.environmentWithoutKeys(environment)
        ).run()
        return CodexLoginStatus.availability(
            statusOutput: String(bytes: output.standardError + output.standardOutput, encoding: .utf8) ?? "",
            hasLoginFile: FileManager.default.fileExists(atPath: codexFolders.userLogin.path)
        )
    }
}
