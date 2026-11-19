#if DEBUG
import AVFoundation
import OSLog

struct HoldFile {
    let audioSource: AudioFileSource

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    static func atLaunch(defaults: UserDefaults) -> HoldFile? {
        guard let path = defaults.string(forKey: "UmiHoldFile") else { return nil }
        return HoldFile(audioSource: AudioFileSource(fileURL: URL(filePath: path)))
    }

    func events() -> AsyncStream<HoldEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: HoldEvent.self)
        let fileURL = audioSource.fileURL
        let playing = Task {
            continuation.yield(.began)
            do {
                try await Task.sleep(for: .seconds(try await Self.duration(of: fileURL)))
            } catch is CancellationError {
                continuation.finish()
                return
            } catch {
                logger.error("The hold file could not be read: \(error.localizedDescription)")
            }
            continuation.yield(.ended)
            continuation.finish()
        }
        continuation.onTermination = { _ in
            playing.cancel()
        }
        return stream
    }

    @concurrent
    private static func duration(of fileURL: URL) async throws -> Double {
        let file = try AVAudioFile(forReading: fileURL)
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
#endif
