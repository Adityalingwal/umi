import Foundation
import OSLog

nonisolated enum FluxSpeechMessage: Sendable {
    case audio(Data)
    case sentenceStarted
    case sentenceEnded(billableCharacters: Int, audioMilliseconds: Int)
}

final class FluxSpeech {
    private static let voice = "flux-divya-hi"
    private static let flush = #"{"type":"Flush"}"#

    private let socket: URLSessionWebSocketTask?
    private let outgoing = AsyncStream.makeStream(of: URLSessionWebSocketTask.Message.self)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var sending: Task<Void, Never>?
    private var isClosed = false

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

    func speak(_ sentence: String) {
        guard let speak = try? JSONEncoder().encode(FluxSpeak(text: sentence)),
              let json = String(bytes: speak, encoding: .utf8) else {
            logger.error("A sentence could not be encoded for the voice")
            return
        }
        outgoing.continuation.yield(.string(json))
        outgoing.continuation.yield(.string(Self.flush))
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        sending?.cancel()
        outgoing.continuation.finish()
        socket?.cancel(with: .normalClosure, reason: nil)
    }

    private func decode(
        _ message: URLSessionWebSocketTask.Message,
        from socket: URLSessionWebSocketTask
    ) throws -> FluxSpeechMessage? {
        if case .data(let audio) = message {
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
            return nil
        case "SpeechStarted":
            return .sentenceStarted
        case "SpeechMetadata":
            return .sentenceEnded(
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
