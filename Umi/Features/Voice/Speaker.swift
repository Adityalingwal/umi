import Foundation

struct Speaker {
    private let key: DeepgramKey?
    private let session: URLSession

    static func atLaunch(bundleURL: URL, session: URLSession) async -> Speaker {
        let key = await DeepgramKey.fromBundle(bundleURL)
        return Speaker(key: key, session: session)
    }

    func answer() throws -> SpokenAnswer {
        guard let key else { throw SpeechError.keyMissing }
        let socket = FluxSpeech(key: key, session: session)
        return SpokenAnswer(socket: socket)
    }
}
