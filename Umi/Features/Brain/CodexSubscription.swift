import Foundation
import OSLog

final class CodexSubscription: Brain {
    private static let model = "gpt-6.2-sol"
    private static let effort = "low"
    private static let removedVariables: Set<String> = ["OPENAI_API_KEY", "CODEX_API_KEY", "CODEX_ACCESS_TOKEN"]

    private let executable: CodexExecutable
    private let folders: CodexFolders
    private let environment: [String: String]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private var hasCatalog = false
    private var connection: CodexConnection?
    private var connectionLogin: CodexLoginStamp?
    private var starting: Task<(CodexConnection, CodexLoginStamp), any Error>?
    private var ahead: Task<CodexThread, any Error>?

    init(executable: CodexExecutable, folders: CodexFolders, environment: [String: String]) {
        self.executable = executable
        self.folders = folders
        self.environment = environment
    }

    static func childEnvironment(from environment: [String: String], home: URL) -> [String: String] {
        var child = environment.filter { !removedVariables.contains($0.key) }
        child["CODEX_HOME"] = home.path
        return child
    }

    func prepare() {
        guard ahead == nil else { return }
        ahead = Task { [weak self] in
            guard let self else { throw CancellationError() }
            do {
                return try await startThread()
            } catch {
                let reason = (error as? BrainError).map { String(describing: $0) } ?? "unexpected"
                logger.error("Codex could not be started ahead: \(reason, privacy: .public)")
                throw error
            }
        }
    }

    func stop() {
        ahead?.cancel()
        ahead = nil
        starting?.cancel()
        starting = nil
        connection?.stop()
        connection = nil
    }

    func answer(_ question: BrainQuestion) -> AsyncThrowingStream<String, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let answering = Task { [weak self] in
            guard let self else { return }
            do {
                let thread = try await currentThread()
                defer { prepare() }
                try await CodexTurn(thread: thread, logger: logger).relay(
                    answerTo: question,
                    effort: Self.effort,
                    into: continuation
                )
                continuation.finish()
            } catch is CancellationError {
                continuation.finish(throwing: CancellationError())
            } catch let error as BrainError {
                continuation.finish(throwing: error)
            } catch {
                logger.error("Codex failed unexpectedly: \(error.localizedDescription)")
                continuation.finish(throwing: BrainError.failed(.codex))
            }
        }
        continuation.onTermination = { _ in
            answering.cancel()
        }
        return stream
    }

    // A warm Codex keeps the login it started with, so a changed login file means starting it again.
    private func currentThread() async throws -> CodexThread {
        let thread = try await readyThread()
        let login = CodexLoginStamp(of: folders.userLogin)
        guard login != thread.login else { return thread }
        thread.connection.release(thread: thread.id)
        guard login != nil else { throw BrainError.notSignedIn(.codex) }
        logger.notice("The Codex login file changed, so Codex starts again")
        thread.connection.stop()
        if connection === thread.connection {
            connection = nil
        }
        return try await startThread()
    }

    private func readyThread() async throws -> CodexThread {
        if let waiting = ahead {
            ahead = nil
            if let thread = try? await waiting.value, thread.connection.isRunning {
                return thread
            }
            logger.notice("No Codex thread was ready ahead, starting one now")
        }
        return try await startThread()
    }

    private func startThread() async throws -> CodexThread {
        let (connection, login) = try await runningConnection()
        try await folders.prepare()
        let result = try await connection.request("thread/start", [
            "ephemeral": true,
            "baseInstructions": UmiPrompt.system,
            "sandbox": "read-only",
            "approvalPolicy": "never",
            "model": Self.model,
            "cwd": folders.work.path
        ])
        guard let threadID = (result["thread"] as? [String: Any])?["id"] as? String else {
            throw BrainError.failed(.codex)
        }
        let model = result["model"] as? String ?? Self.model
        return CodexThread(connection: connection, id: threadID, model: model, login: login)
    }

    private func runningConnection() async throws -> (CodexConnection, CodexLoginStamp) {
        if let connection, let connectionLogin, connection.isRunning {
            return (connection, connectionLogin)
        }
        if let starting {
            return try await starting.value
        }
        let start = Task { try await self.startConnection() }
        starting = start
        defer { starting = nil }
        let (connection, login) = try await start.value
        self.connection = connection
        connectionLogin = login
        return (connection, login)
    }

    private func startConnection() async throws -> (CodexConnection, CodexLoginStamp) {
        guard let executableURL = executable.locate(environment: environment) else {
            throw BrainError.notInstalled(.codex)
        }
        try await folders.prepare()
        guard let login = CodexLoginStamp(of: folders.userLogin) else {
            throw BrainError.notSignedIn(.codex)
        }
        if !hasCatalog {
            try await buildCatalog(executableURL: executableURL)
            hasCatalog = true
        }
        let connection = try launch(
            executableURL,
            arguments: CodexArguments.answering(model: Self.model, catalogPath: folders.catalog.path)
        )
        do {
            try await CodexGate.greet(connection)
            try await CodexGate.checkSignIn(connection)
            try await CodexGate.checkOnlyModel(connection, model: Self.model)
        } catch {
            connection.stop()
            throw error
        }
        logger.notice("Codex is ready with only \(Self.model, privacy: .public) and no tools")
        return (connection, login)
    }

    private func buildCatalog(executableURL: URL) async throws {
        let bootstrap = try launch(executableURL, arguments: CodexArguments.bootstrap(model: Self.model))
        defer { bootstrap.stop() }
        try await CodexGate.greet(bootstrap)
        try await CodexGate.checkSignIn(bootstrap)
        _ = try await bootstrap.request("model/list", ["includeHidden": true])
        do {
            try await CodexCatalog.write(model: Self.model, from: folders.modelsCache, to: folders.catalog)
        } catch let error as BrainError {
            throw error
        } catch {
            logger.error("The Codex catalog could not be built: \(error.localizedDescription)")
            throw BrainError.codexCannotUseModel
        }
        logger.notice("Built the one-model Codex catalog")
    }

    private func launch(_ executableURL: URL, arguments: [String]) throws -> CodexConnection {
        let connection = CodexConnection(
            executableURL: executableURL,
            arguments: arguments,
            environment: Self.childEnvironment(from: environment, home: folders.home),
            workingDirectory: folders.work
        )
        do {
            try connection.start()
        } catch {
            logger.error("Codex did not start: \(error.localizedDescription)")
            throw BrainError.didNotStart(.codex)
        }
        return connection
    }
}
