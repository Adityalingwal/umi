import Foundation
import OSLog

final class ClaudeSubscription: Brain {
    private static let model = "claude-fable-5-2"
    private static let effort = "low"

    private let executable: ClaudeExecutable
    private let environment: [String: String]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private var spare: ClaudeProcess?

    init(executable: ClaudeExecutable, environment: [String: String]) {
        self.executable = executable
        self.environment = environment
    }

    static func childEnvironment(from environment: [String: String]) -> [String: String] {
        environment.filter { $0.key != "ANTHROPIC_API_KEY" }
    }

    func prepare() {
        do {
            spare = try startProcess()
        } catch {
            logger.error("Claude could not be started ahead: \(String(describing: error), privacy: .public)")
        }
    }

    func stop() {
        spare?.stop()
        spare = nil
    }

    func answer(_ question: BrainQuestion) -> AsyncThrowingStream<String, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let answering = Task { [weak self] in
            guard let self else { return }
            do {
                let process = try takeProcess()
                prepare()
                defer { process.stop() }
                try await relay(answerTo: question, from: process, into: continuation)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            answering.cancel()
        }
        return stream
    }

    private func relay(
        answerTo question: BrainQuestion,
        from process: ClaudeProcess,
        into continuation: AsyncThrowingStream<String, any Error>.Continuation
    ) async throws {
        for try await line in try await process.ask(question) {
            try Task.checkCancellation()
            switch ClaudeStreamEvent(line: line) {
            case let .started(apiKeySource, model):
                logger.notice("Claude stream started, model \(model, privacy: .public)")
                logger.notice("Claude key source: \(apiKeySource, privacy: .public)")
            case .text(let piece):
                continuation.yield(piece)
            case .finished:
                return
            case .failed:
                throw BrainError.claudeFailed
            case .other:
                continue
            }
        }
        throw BrainError.answerEndedEarly
    }

    private func takeProcess() throws -> ClaudeProcess {
        defer { spare = nil }
        if let spare, spare.isRunning {
            return spare
        }
        return try startProcess()
    }

    private func startProcess() throws -> ClaudeProcess {
        guard let executableURL = executable.locate(environment: environment) else {
            throw BrainError.claudeNotInstalled
        }
        let process = ClaudeProcess(
            executableURL: executableURL,
            arguments: Self.arguments,
            environment: Self.childEnvironment(from: environment)
        )
        do {
            try process.start()
        } catch {
            logger.error("Claude did not start: \(error.localizedDescription)")
            throw BrainError.claudeDidNotStart
        }
        return process
    }

    private static let arguments = [
        "-p",
        "--input-format", "stream-json",
        "--output-format", "stream-json",
        "--verbose",
        "--include-partial-messages",
        "--model", model,
        "--effort", effort,
        "--system-prompt", ClaudePrompt.system,
        "--tools", "",
        "--setting-sources", "",
        "--strict-mcp-config",
        "--no-session-persistence"
    ]
}
