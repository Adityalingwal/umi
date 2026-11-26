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

    // A check that could not finish gives no answer, so Settings keeps what it showed before.
    func availability(of brain: BrainKind) async -> BrainAvailability? {
        do {
            switch brain {
            case .claude: return try await claudeAvailability()
            case .codex: return try await codexAvailability()
            }
        } catch is CancellationError {
            return nil
        } catch StatusCommand.Failure.tookTooLong {
            logger.error("The \(brain.title, privacy: .public) check took too long")
            return nil
        } catch {
            logger.error("The \(brain.title, privacy: .public) check could not run")
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

    // The status runs exactly as the answers do: Umi's Codex home with the linked login file, the file store only,
    // so it never reaches the Keychain. Without the user's login file there is nothing to link, so nothing runs.
    private func codexAvailability() async throws -> BrainAvailability {
        guard let executableURL = codexExecutable.locate(environment: environment) else { return .notInstalled }
        guard FileManager.default.fileExists(atPath: codexFolders.userLogin.path) else { return .notSignedIn(.noLogin) }
        do {
            try await codexFolders.prepare()
        } catch BrainError.notSignedIn {
            return .notSignedIn(.noLogin)
        }
        let output = try await StatusCommand(
            executableURL: executableURL,
            arguments: CodexArguments.loginStatus,
            environment: CodexSubscription.childEnvironment(from: environment, home: codexFolders.home)
        ).run()
        return CodexLoginStatus.availability(
            statusOutput: String(bytes: output.standardError + output.standardOutput, encoding: .utf8) ?? ""
        )
    }
}
