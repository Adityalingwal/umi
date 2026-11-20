import Foundation
import OSLog

nonisolated struct NovaTranscription: Sendable {
    private static let requestTimeout: TimeInterval = 10

    private let key: DeepgramKey
    private let session: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    init(key: DeepgramKey, session: URLSession) {
        self.key = key
        self.session = session
    }

    @concurrent
    func text(of recording: HoldRecording) async throws -> String {
        guard let request = request() else { throw SpeechError.serviceFailed }
        let (data, response) = try await send(request, body: recording.linear16)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            logger.error("Nova-3 answered HTTP \(status, privacy: .public)")
            throw SpeechError(httpStatus: status)
        }
        let decoded = try? JSONDecoder().decode(NovaResponse.self, from: data)
        guard let transcript = decoded?.results.channels.first?.alternatives.first?.transcript else {
            logger.error("Nova-3 sent an answer without a transcript")
            throw SpeechError.serviceFailed
        }
        logger.notice("Nova-3 heard \(transcript.count, privacy: .public) characters")
        return transcript
    }

    private func send(_ request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        do {
            return try await session.upload(for: request, from: body)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            logger.error("Nova-3 request failed, URL error \(error.code.rawValue, privacy: .public)")
            throw SpeechError(error)
        }
    }

    private func request() -> URLRequest? {
        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")
        components?.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: "multi"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(SpeechAudioConverter.sampleRate)))
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("Token \(key.value)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/raw", forHTTPHeaderField: "Content-Type")
        return request
    }
}

private nonisolated struct NovaResponse: Decodable {
    struct Results: Decodable {
        let channels: [Channel]
    }

    struct Channel: Decodable {
        let alternatives: [Alternative]
    }

    struct Alternative: Decodable {
        let transcript: String
    }

    let results: Results
}
