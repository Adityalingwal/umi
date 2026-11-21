import Foundation
import OSLog

final class CodexConnection {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private var lastRequestID = 0
    private var replies: [Int: CheckedContinuation<Data, any Error>] = [:]
    private var threads: [String: AsyncStream<CodexEvent>.Continuation] = [:]
    private var writing: Task<Void, Never>?
    private var reading: Task<Void, Never>?
    private var hasEnded = false

    var isRunning: Bool { process.isRunning && !hasEnded }

    init(executableURL: URL, arguments: [String], environment: [String: String], workingDirectory: URL) {
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    // FileHandle.bytes reads on one serial queue shared by the whole app, so a long-lived Codex reader
    // there would block the Claude plug's reader; this handler reads on its own.
    func start() throws {
        try process.run()
        let (chunks, chunkContinuation) = AsyncStream.makeStream(of: Data.self)
        output.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                chunkContinuation.finish()
            } else {
                chunkContinuation.yield(chunk)
            }
        }
        reading = Task { [weak self] in
            var pending = Data()
            for await chunk in chunks {
                pending.append(chunk)
                while let end = pending.firstIndex(of: UInt8(ascii: "\n")) {
                    let line = Data(pending[pending.startIndex..<end])
                    pending.removeSubrange(pending.startIndex...end)
                    self?.receive(line)
                }
            }
            self?.end()
        }
    }

    func stop() {
        if process.isRunning {
            process.terminate()
        }
        end()
    }

    func request(_ method: String, _ params: [String: Any] = [:]) async throws -> [String: Any] {
        let id = nextRequestID()
        return try await send(CodexLine.request(id: id, method: method, params: params), awaiting: id)
    }

    func nextRequestID() -> Int {
        lastRequestID += 1
        return lastRequestID
    }

    func send(_ line: Data, awaiting id: Int) async throws -> [String: Any] {
        guard !hasEnded else { throw BrainError.failed(.codex) }
        let reply = try await withCheckedThrowingContinuation { continuation in
            replies[id] = continuation
            write(line)
        }
        let message = try JSONSerialization.jsonObject(with: reply) as? [String: Any]
        return message?["result"] as? [String: Any] ?? [:]
    }

    func notify(_ method: String) throws {
        write(try CodexLine.notification(method: method))
    }

    // The reply is not awaited; only a refusal is logged.
    func fire(_ method: String, _ params: [String: Any]) throws {
        write(try CodexLine.request(id: nextRequestID(), method: method, params: params))
    }

    func events(forThread threadID: String) -> AsyncStream<CodexEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: CodexEvent.self)
        if hasEnded {
            continuation.finish()
        } else {
            threads[threadID] = continuation
        }
        return stream
    }

    func forget(thread threadID: String) {
        threads.removeValue(forKey: threadID)?.finish()
    }

    private func write(_ line: Data) {
        let previous = writing
        let handle = input.fileHandleForWriting
        writing = Task { [weak self] in
            await previous?.value
            do {
                try await Self.write(line, to: handle)
            } catch {
                self?.logger.error("Writing to Codex failed: \(error.localizedDescription)")
                self?.stop()
            }
        }
    }

    @concurrent
    private static func write(_ line: Data, to handle: FileHandle) async throws {
        try handle.write(contentsOf: line)
    }

    private func receive(_ data: Data) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let method = message["method"] as? String
        switch (message["id"], method) {
        case let (id?, method?):
            refuse(id, method: method)
        case let (id as Int, nil):
            reply(to: id, with: message, line: data)
        case let (nil, method?):
            route(method: method, params: message["params"] as? [String: Any] ?? [:])
        default:
            break
        }
    }

    private func refuse(_ id: Any, method: String) {
        logger.error("Codex asked Umi for \(method, privacy: .public); refused")
        do {
            write(try CodexLine.refusal(id: id))
        } catch {
            logger.error("The refusal could not be written: \(error.localizedDescription)")
        }
    }

    private func reply(to id: Int, with message: [String: Any], line: Data) {
        let continuation = replies.removeValue(forKey: id)
        if let error = message["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? 0
            logger.error("Codex refused a request, code \(code, privacy: .public)")
            continuation?.resume(throwing: BrainError.failed(.codex))
        } else if let continuation {
            continuation.resume(returning: line)
        }
    }

    private func route(method: String, params: [String: Any]) {
        guard let threadID = params["threadId"] as? String, let thread = threads[threadID] else { return }
        thread.yield(CodexEvent(method: method, params: params))
    }

    private func end() {
        guard !hasEnded else { return }
        hasEnded = true
        logger.notice("Codex stopped")
        for continuation in replies.values {
            continuation.resume(throwing: BrainError.failed(.codex))
        }
        replies.removeAll()
        for thread in threads.values {
            thread.finish()
        }
        threads.removeAll()
    }
}
