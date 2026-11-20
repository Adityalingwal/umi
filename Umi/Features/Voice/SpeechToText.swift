import Foundation
import OSLog

struct SpeechToText {
    private let key: DeepgramKey?
    private let session: URLSession
    private let fluxEndpoint: URL?

    static func atLaunch(bundleURL: URL, defaults: UserDefaults, session: URLSession) async -> SpeechToText {
        let key = await DeepgramKey.fromBundle(bundleURL)
        #if DEBUG
        if defaults.bool(forKey: "UmiFailFlux") {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
                .notice("Flux will fail on purpose (-UmiFailFlux)")
            // Nothing listens on this port, so Flux fails at once and nothing leaves the Mac.
            return SpeechToText(key: key, session: session, fluxEndpoint: URL(string: "wss://127.0.0.1:9"))
        }
        #endif
        return SpeechToText(key: key, session: session, fluxEndpoint: FluxTranscription.endpoint)
    }

    func hearing(from source: any AudioSource) throws -> HoldHearing {
        guard let key else { throw SpeechError.keyMissing }
        return HoldHearing(
            flux: FluxTranscription(key: key, endpoint: fluxEndpoint, source: source, session: session),
            nova: NovaTranscription(key: key, session: session)
        )
    }
}
