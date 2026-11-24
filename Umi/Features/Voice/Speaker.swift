import Foundation

struct Speaker {
    private let key: DeepgramKey?
    private let session: URLSession
    #if DEBUG
    private let speechFile: SpeechFile?
    private let cutVoiceAfter: Int?
    #endif

    static func atLaunch(bundleURL: URL, defaults: UserDefaults, session: URLSession) async -> Speaker {
        let key = await DeepgramKey.fromBundle(bundleURL)
        #if DEBUG
        let speechFile = SpeechFile.atLaunch(defaults: defaults)
        speechFile?.startEmpty()
        let cutVoiceAfter = defaults.integer(forKey: "UmiCutVoiceAfter")
        return Speaker(key: key, session: session, speechFile: speechFile,
                       cutVoiceAfter: cutVoiceAfter > 0 ? cutVoiceAfter : nil)
        #else
        return Speaker(key: key, session: session)
        #endif
    }

    func answer() throws -> SpokenAnswer {
        guard let key else { throw SpeechError.keyMissing }
        let socket = FluxSpeech(key: key, session: session)
        #if DEBUG
        socket.failAfterMilliseconds = cutVoiceAfter
        return SpokenAnswer(socket: socket, speechFile: speechFile)
        #else
        return SpokenAnswer(socket: socket)
        #endif
    }
}
