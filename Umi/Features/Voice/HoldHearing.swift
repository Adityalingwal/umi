import Foundation
import OSLog

final class HoldHearing {
    // Halfway, on a log scale, between #9's synthetic room hiss (0.016) and white noise (0.34).
    // To be set from the real microphone.
    private static let silencePeak = 0.07

    private let flux: FluxTranscription
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    init(flux: FluxTranscription) {
        self.flux = flux
    }

    func start() {
        flux.start()
    }

    func cancel() {
        flux.cancel()
    }

    func finish() async throws -> Heard {
        let text = try await flux.finish()
        let peak = flux.recording.peakLevel
        logger.notice("Hold peak level \(peak, format: .fixed(precision: 4), privacy: .public)")
        if !text.isEmpty {
            return .words(text)
        }
        return peak < Self.silencePeak ? .silence : .soundWithoutWords
    }
}
