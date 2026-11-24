import Foundation
import OSLog

final class ClaudeSubscription: Brain {
    private static let model = "claude-fable-5-2"
    private static let effort = "low"

    private let executable: ClaudeExecutable
    private let environment: [String: String]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private var spare: ClaudeProcess?
    private var answeringProcess: ClaudeProcess?

    init(executable: ClaudeExecutable, environment: [String: String]) {
        self.executable = executable
        self.environment = environment
    }

    private static let removedVariables: Set<String> = ["ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL"]

    static func childEnvironment(from environment: [String: String]) -> [String: String] {
        environment.filter { !removedVariables.contains($0.key) }
    }

    func prepare() {
        do {
            spare = try startProcess()
        } catch {
            logger.error("Claude could not be started ahead: \(String(describing: error), privacy: .public)")
        }
    }

    func prepareIfNeeded() {
        guard spare?.isRunning != true else { return }
        prepare()
    }

    func stop() {
        spare?.stop()
        spare = nil
        answeringProcess?.stop()
        answeringProcess = nil
    }

    func answer(_ question: BrainQuestion) -> AsyncThrowingStream<String, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let answering = Task { [weak self] in
            guard let self else { return }
            do {
                let process = try takeProcess()
                answeringProcess = process
                prepare()
                defer {
                    process.stop()
                    if answeringProcess === process {
                        answeringProcess = nil
                    }
                }
                try await relay(answerTo: question, from: process, into: continuation)
                continuation.finish()
            } catch is CancellationError {
                logger.notice("Claude was stopped before its answer ended")
                continuation.finish(throwing: CancellationError())
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
        var failure: BrainError?
        var hasText = false
        for try await line in try await process.ask(question) {
            try Task.checkCancellation()
            switch ClaudeStreamEvent(line: line) {
            case let .started(apiKeySource, model):
                logger.notice("Claude stream started, model \(model, privacy: .public)")
                logger.notice("Claude key source: \(apiKeySource, privacy: .public)")
            case .text(let piece):
                hasText = true
                continuation.yield(piece)
            case .blockEnded where hasText:
                logger.notice("Claude's answer text ended")
                return
            case .apiError(let error):
                logger.error("Claude reported an error: \(String(describing: error), privacy: .public)")
                failure = error
            case .connectionLost:
                logger.error("Claude could not reach its server, stopping without retries")
                throw BrainError.noInternet
            case .finished:
                if let failure {
                    throw failure
                }
                return
            case .failed:
                throw failure ?? .failed(.claude)
            case .blockEnded, .other:
                continue
            }
        }
        throw BrainError.answerEndedEarly(.claude)
    }

    // A spare keeps running after Claude Code is uninstalled, so a missing executable stops it.
    private func takeProcess() throws -> ClaudeProcess {
        defer { spare = nil }
        guard executable.locate(environment: environment) != nil else {
            spare?.stop()
            throw BrainError.notInstalled(.claude)
        }
        if let spare, spare.isRunning {
            return spare
        }
        return try startProcess()
    }

    private func startProcess() throws -> ClaudeProcess {
        guard let executableURL = executable.locate(environment: environment) else {
            throw BrainError.notInstalled(.claude)
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
            throw BrainError.didNotStart(.claude)
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
        "--system-prompt", UmiPrompt.system,
        "--tools", "",
        "--setting-sources", "",
        "--strict-mcp-config",
        "--no-session-persistence"
    ]
}
