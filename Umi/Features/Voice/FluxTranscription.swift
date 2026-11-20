import Foundation
import OSLog

final class FluxTranscription {
    private static let tail = Duration.milliseconds(100)
    private static let finalTextWait = Duration.seconds(5)
    private static let endSilence = Data(count: 6_400)
    private static let forceEndTurn = #"{"type":"ForceEndTurn"}"#

    private let socket: URLSessionWebSocketTask?
    private let source: any AudioSource
    private let converter = SpeechAudioConverter()
    private let audio = AsyncStream.makeStream(of: Data.self)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var connection = FluxConnection.opening
    private(set) var recording = HoldRecording()
    private var isEndOfTurnForced = false
    private var isFinalTextReceived = false
    private var finishedTurns: [String] = []
    private var stateWaiters: [CheckedContinuation<Void, Never>] = []
    private var hearing: Task<Void, Never>?
    private var receiving: Task<Void, Never>?
    private var sending: Task<Void, Never>?

    static var endpoint: URL? {
        var components = URLComponents(string: "wss://api.deepgram.com/v2/listen")
        components?.queryItems = [
            URLQueryItem(name: "model", value: "flux-general-multi"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(SpeechAudioConverter.sampleRate))),
            URLQueryItem(name: "eot_threshold", value: "0.9"),
            URLQueryItem(name: "eot_timeout_ms", value: "60000")
        ]
        return components?.url
    }

    init(key: DeepgramKey, endpoint: URL?, source: any AudioSource, session: URLSession) {
        socket = endpoint.map { session.webSocketTask(with: $0, protocols: ["token", key.value]) }
        self.source = source
    }

    func start() {
        startHearing()
        guard let socket else {
            connection = .failed
            return
        }
        socket.resume()
        startReceiving(from: socket)
        startSending(to: socket)
    }

    func finish() async throws -> String {
        try? await Task.sleep(for: Self.tail)
        hearing?.cancel()
        let deadline = Task { [weak self] in
            try? await Task.sleep(for: Self.finalTextWait)
            self?.timeOut()
        }
        defer {
            deadline.cancel()
            cancel()
        }
        await sending?.value
        guard connection == .open, let socket else { throw SpeechError.connectionFailed }
        isEndOfTurnForced = true
        try await socket.send(.data(Self.endSilence))
        try await socket.send(.string(Self.forceEndTurn))
        while connection == .open, !isFinalTextReceived {
            await nextStateChange()
        }
        guard isFinalTextReceived else {
            throw connection == .timedOut ? SpeechError.noFinalText : SpeechError.connectionFailed
        }
        return finishedTurns.joined(separator: " ")
    }

    func cancel() {
        hearing?.cancel()
        receiving?.cancel()
        sending?.cancel()
        audio.continuation.finish()
        socket?.cancel(with: .normalClosure, reason: nil)
        if connection == .opening || connection == .open {
            connection = .closed
        }
        stateChanged()
    }

    private func startHearing() {
        let chunks = source.chunks()
        let output = audio.continuation
        hearing = Task { [weak self, converter, logger] in
            do {
                for try await chunk in chunks {
                    let audio = converter.linear16(from: chunk)
                    self?.recording.append(audio)
                    output.yield(audio)
                }
            } catch is CancellationError {
            } catch {
                logger.error("The question's audio stopped: \(error.localizedDescription)")
            }
            output.finish()
        }
    }

    private func startReceiving(from socket: URLSessionWebSocketTask) {
        receiving = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    self?.handle(message)
                } catch {
                    self?.connectionEnded(error, response: socket.response)
                    return
                }
            }
        }
    }

    private func startSending(to socket: URLSessionWebSocketTask) {
        let stream = audio.stream
        sending = Task { [weak self] in
            guard await self?.waitUntilOpen() == true else { return }
            for await data in stream where !data.isEmpty {
                do {
                    try await socket.send(.data(data))
                } catch {
                    self?.connectionEnded(error, response: socket.response)
                    return
                }
            }
        }
    }

    private func waitUntilOpen() async -> Bool {
        while connection == .opening {
            await nextStateChange()
        }
        return connection == .open
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let decoded = try? JSONDecoder().decode(FluxMessage.self, from: Data(text.utf8)) else {
            return
        }
        switch (decoded.type, decoded.event) {
        case ("Connected", _):
            guard connection == .opening else { return }
            connection = .open
            logger.notice("Deepgram connected")
        case ("TurnInfo", "EndOfTurn"):
            if let transcript = decoded.transcript, !transcript.isEmpty {
                finishedTurns.append(transcript)
            }
            isFinalTextReceived = isEndOfTurnForced && decoded.trigger == "manual"
        case ("Warning", _) where decoded.code == "FORCE_END_TURN_NO_ACTIVE_TURN":
            isFinalTextReceived = isEndOfTurnForced
        case ("Error", _):
            logger.error("Deepgram sent an error: \(decoded.code ?? "none", privacy: .public)")
            connection = .failed
        default:
            return
        }
        stateChanged()
    }

    private func connectionEnded(_ error: any Error, response: URLResponse?) {
        guard connection == .opening || connection == .open else { return }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        logger.error("Deepgram connection ended, HTTP \(status, privacy: .public): \(error.localizedDescription)")
        connection = .failed
        stateChanged()
    }

    private func timeOut() {
        guard connection == .opening || connection == .open, !isFinalTextReceived else { return }
        logger.error("Deepgram gave no final text in time")
        connection = .timedOut
        stateChanged()
    }

    private func nextStateChange() async {
        await withCheckedContinuation { stateWaiters.append($0) }
    }

    private func stateChanged() {
        let waiters = stateWaiters
        stateWaiters = []
        waiters.forEach { $0.resume() }
    }
}

private enum FluxConnection {
    case opening
    case open
    case failed
    case timedOut
    case closed
}

private nonisolated struct FluxMessage: Decodable {
    let type: String
    let event: String?
    let transcript: String?
    let code: String?
    let trigger: String?
}
