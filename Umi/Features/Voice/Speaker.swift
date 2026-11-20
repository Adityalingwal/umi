import Foundation

struct Speaker {
    private let key: DeepgramKey?
    private let session: URLSession
    #if DEBUG
    private let speechFile: SpeechFile?
    #endif

    static func atLaunch(bundleURL: URL, defaults: UserDefaults, session: URLSession) async -> Speaker {
        let key = await DeepgramKey.fromBundle(bundleURL)
        #if DEBUG
        let speechFile = SpeechFile.atLaunch(defaults: defaults)
        speechFile?.startEmpty()
        return Speaker(key: key, session: session, speechFile: speechFile)
        #else
        return Speaker(key: key, session: session)
        #endif
    }

    func answer() throws -> SpokenAnswer {
        guard let key else { throw SpeechError.keyMissing }
        let socket = FluxSpeech(key: key, session: session)
        #if DEBUG
        return SpokenAnswer(socket: socket, speechFile: speechFile)
        #else
        return SpokenAnswer(socket: socket)
        #endif
    }
}
