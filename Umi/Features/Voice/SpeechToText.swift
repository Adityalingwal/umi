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
            return SpeechToText(key: key, session: session, fluxEndpoint: nil)
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
