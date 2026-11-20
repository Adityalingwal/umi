import Foundation
import OSLog

final class HoldHearing {
    // Checked on a MacBook's built-in microphone: silent holds peaked at 0.019-0.031,
    // a cough, a tap or "hmm" at 0.143-0.831.
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
            let reason = (error as? SpeechError).map { "\($0)" } ?? "socket error"
            logger.error("Flux failed (\(reason, privacy: .public)), asking Nova-3")
            guard !flux.recording.linear16.isEmpty else { return "" }
            return try await nova.text(of: flux.recording)
        }
    }
}
