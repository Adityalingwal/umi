import Foundation
import OSLog

final class HoldHearing {
    // Halfway, on a log scale, between #9's synthetic room hiss (0.016) and white noise (0.34).
    // To be set from the real microphone.
    private static let silencePeak = 0.07

    private let flux: FluxTranscription
    private let nova: NovaTranscription
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    init(flux: FluxTranscription, nova: NovaTranscription) {
        self.flux = flux
        self.nova = nova
    }

    func start() {
        flux.start()
    }

    func cancel() {
        flux.cancel()
    }

    func finish() async throws -> Heard {
        let text = try await transcribe()
        let peak = flux.recording.peakLevel
        logger.notice("Hold peak level \(peak, format: .fixed(precision: 4), privacy: .public)")
        if !text.isEmpty {
            return .words(text)
        }
        return peak < Self.silencePeak ? .silence : .soundWithoutWords
    }

    private func transcribe() async throws -> String {
        do {
            return try await flux.finish()
        } catch let error as AudioSourceError {
            throw error
        } catch {
            try Task.checkCancellation()
            logger.error("Flux failed (\(String(describing: error), privacy: .public)), asking Nova-3")
            guard !flux.recording.linear16.isEmpty else { return "" }
            return try await nova.text(of: flux.recording)
        }
    }
}
