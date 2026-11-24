import Foundation
import OSLog
import Synchronization

nonisolated enum FluxSpeechMessage: Sendable {
    case connected
    case audio(Data)
    case turnStarted
    case turnEnded(billableCharacters: Int, audioMilliseconds: Int)
}

final class FluxSpeech {
    private static let voice = "flux-divya-hi"
    private static let flush = #"{"type":"Flush"}"#
    // Deepgram closes a voice socket idle for about 60 s; #14 kept one open 33 min with a ping every 20 s.
    private static let keepAliveInterval = Duration.seconds(20)

    private let socket: URLSessionWebSocketTask?
    private let outgoing = AsyncStream.makeStream(of: URLSessionWebSocketTask.Message.self)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var sending: Task<Void, Never>?
    private var keepingAlive: Task<Void, Never>?
    private var isClosed = false
    #if DEBUG
    var failAfterMilliseconds: Int?
    private var receivedAudioBytes = 0
    #endif

    private static var endpoint: URL? {
        var components = URLComponents(string: "wss://api.deepgram.com/v2/speak")
        components?.queryItems = [
            URLQueryItem(name: "model", value: voice),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(SpeechQueue.sampleRate)))
        ]
        return components?.url
    }

    init(key: DeepgramKey, session: URLSession) {
        socket = Self.endpoint.map { session.webSocketTask(with: $0, protocols: ["token", key.value]) }
    }

    func messages() -> AsyncThrowingStream<FluxSpeechMessage, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: FluxSpeechMessage.self)
        guard let socket else {
            continuation.finish(throwing: SpeechError.serviceFailed)
            return stream
        }
        socket.resume()
        let receiving = Task { [weak self] in
            do {
                while true {
                    let message = try await socket.receive()
                    if let decoded = try self?.decode(message, from: socket) {
                        continuation.yield(decoded)
                    }
                }
            } catch {
                continuation.finish(throwing: self?.failure(after: error, response: socket.response))
            }
        }
        continuation.onTermination = { _ in
            receiving.cancel()
        }
        return stream
    }

    func send(_ text: String) throws {
        guard let json = String(bytes: try JSONEncoder().encode(FluxSpeak(text: text)), encoding: .utf8) else {
            throw SpeechError.serviceFailed
        }
        outgoing.continuation.yield(.string(json))
    }

    func flush() {
        outgoing.continuation.yield(.string(Self.flush))
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        sending?.cancel()
        keepingAlive?.cancel()
        outgoing.continuation.finish()
        socket?.cancel(with: .normalClosure, reason: nil)
    }

    private func decode(
        _ message: URLSessionWebSocketTask.Message,
        from socket: URLSessionWebSocketTask
    ) throws -> FluxSpeechMessage? {
        if case .data(let audio) = message {
            #if DEBUG
            try failIfCutDue(after: audio)
            #endif
            return .audio(audio)
        }
        guard case .string(let text) = message else { return nil }
        let event = try? JSONDecoder().decode(FluxSpeechEvent.self, from: Data(text.utf8))
        return try handle(event, from: socket)
    }

    private func handle(_ event: FluxSpeechEvent?, from socket: URLSessionWebSocketTask) throws -> FluxSpeechMessage? {
        switch event?.type {
        case "Connected":
            logger.notice("The voice connected")
            startSending(to: socket)
            keepAlive(socket)
            return .connected
        case "SpeechStarted":
            return .turnStarted
        case "SpeechMetadata":
            return .turnEnded(
                billableCharacters: event?.billableCharacterCount ?? 0,
                audioMilliseconds: event?.audioDurationMilliseconds ?? 0
            )
        case "Warning":
            logger.notice("The voice sent a warning: \(event?.code ?? "none", privacy: .public)")
            return nil
        case "Error":
            logger.error("The voice sent an error: \(event?.code ?? "none", privacy: .public)")
            throw SpeechError.serviceFailed
        default:
            return nil
        }
    }

    #if DEBUG
    private func failIfCutDue(after audio: Data) throws {
        receivedAudioBytes += audio.count
        let received = receivedAudioBytes * 1_000 / (MemoryLayout<Int16>.size * Int(SpeechQueue.sampleRate))
        guard let limit = failAfterMilliseconds, received >= limit else { return }
        logger.notice("The voice fails on purpose after \(received, privacy: .public) ms of audio (-UmiCutVoiceAfter)")
        throw SpeechError.serviceFailed
    }
    #endif

    private func startSending(to socket: URLSessionWebSocketTask) {
        guard sending == nil, !isClosed else { return }
        let messages = outgoing.stream
        sending = Task { [logger] in
            for await message in messages {
                do {
                    try await socket.send(message)
                } catch {
                    logger.error("The voice could not be sent text: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    private func keepAlive(_ socket: URLSessionWebSocketTask) {
        guard keepingAlive == nil, !isClosed else { return }
        keepingAlive = Task { [logger] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.keepAliveInterval)
                guard !Task.isCancelled else { return }
                do {
                    try await Self.ping(socket)
                    logger.notice("The voice's keep-alive ping came back")
                } catch {
                    guard !Task.isCancelled else { return }
                    logger.error("The voice's keep-alive ping failed: \(error.localizedDescription)")
                    return
                }
            }
        }
    }

    private static func ping(_ socket: URLSessionWebSocketTask) async throws {
        let answer = PingAnswer()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            socket.sendPing { error in
                // URLSession called this twice when the socket closed while a ping waited for its pong.
                guard answer.isFirst() else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func failure(after error: any Error, response: URLResponse?) -> (any Error)? {
        guard !isClosed else { return nil }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        logger.error("The voice's connection ended, HTTP \(status, privacy: .public): \(error.localizedDescription)")
        if let error = error as? SpeechError {
            return error
        }
        if status == 401 || status == 403 {
            return SpeechError.keyRefused
        }
        return (error as? URLError).map(SpeechError.init) ?? SpeechError.connectionFailed
    }
}

private nonisolated final class PingAnswer: Sendable {
    private let isAnswered = Atomic(false)

    func isFirst() -> Bool {
        !isAnswered.exchange(true, ordering: .relaxed)
    }
}

private nonisolated struct FluxSpeak: Encodable {
    let type = "Speak"
    let text: String
}

private nonisolated struct FluxSpeechEvent: Decodable {
    let type: String
    let code: String?
    let billableCharacterCount: Int?
    let audioDurationMilliseconds: Int?

    private enum CodingKeys: String, CodingKey {
        case type
        case code
        case billableCharacterCount = "billable_character_count"
        case audioDurationMilliseconds = "audio_duration_ms"
    }
}
