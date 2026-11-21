import OSLog

struct CodexTurn {
    private static let answerItemTypes: Set<String> = ["userMessage", "agentMessage", "reasoning"]

    let thread: CodexThread
    let logger: Logger

    func relay(
        answerTo question: BrainQuestion,
        effort: String,
        into continuation: AsyncThrowingStream<String, any Error>.Continuation
    ) async throws {
        let connection = thread.connection
        try await CodexGate.checkSignIn(connection)
        try Task.checkCancellation()
        let events = connection.events(forThread: thread.id)
        defer { connection.forget(thread: thread.id) }
        let id = connection.nextRequestID()
        let line = try await CodexTurnRequest.line(id: id, threadID: thread.id, effort: effort, question: question)
        let started = try await connection.send(line, awaiting: id)
        guard let turnID = (started["turn"] as? [String: Any])?["id"] as? String else {
            throw BrainError.failed(.codex)
        }
        do {
            try await follow(events, turnID: turnID, into: continuation)
        } catch is CancellationError {
            interrupt(turnID)
            throw CancellationError()
        }
    }

    private func follow(
        _ events: AsyncStream<CodexEvent>,
        turnID: String,
        into continuation: AsyncThrowingStream<String, any Error>.Continuation
    ) async throws {
        var pieces = 0
        var failure: BrainError?
        var items: [String: Int] = [:]
        for await event in events where event.turnID == turnID {
            try Task.checkCancellation()
            switch event {
            case .text(_, let piece):
                pieces += 1
                continuation.yield(piece)
            case .itemStarted(_, let type):
                items[type, default: 0] += 1
            case let .error(_, error, willRetry) where willRetry && error == .noInternet:
                logger.error("Codex could not reach its server, stopping without retries")
                interrupt(turnID)
                throw error
            case let .error(_, error, willRetry) where !willRetry:
                failure = error
            case let .turnEnded(_, status, error):
                log(items, pieces: pieces)
                return try finish(status: status, error: error ?? failure, hasText: pieces > 0)
            case .error, .other:
                continue
            }
        }
        try Task.checkCancellation()
        throw BrainError.answerEndedEarly(.codex)
    }

    private func finish(status: String, error: BrainError?, hasText: Bool) throws {
        switch status {
        case "completed" where hasText:
            return
        case "completed":
            throw BrainError.answerEndedEarly(.codex)
        default:
            logger.error("Codex's turn ended as \(status, privacy: .public)")
            throw error ?? .failed(.codex)
        }
    }

    private func interrupt(_ turnID: String) {
        do {
            try thread.connection.fire("turn/interrupt", ["threadId": thread.id, "turnId": turnID])
            logger.notice("Asked Codex to interrupt its turn")
        } catch {
            logger.error("Codex's turn could not be interrupted: \(error.localizedDescription)")
        }
    }

    private func log(_ items: [String: Int], pieces: Int) {
        let counts = items.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        let toolItems = items.filter { !Self.answerItemTypes.contains($0.key) }.values.reduce(0, +)
        let summary = (counts + ["tool items \(toolItems)", "text pieces \(pieces)"]).joined(separator: ", ")
        logger.notice("Codex answered with model \(thread.model, privacy: .public): \(summary, privacy: .public)")
    }
}
