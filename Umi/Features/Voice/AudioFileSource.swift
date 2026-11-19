#if DEBUG
import AVFoundation
import OSLog

nonisolated struct AudioFileSource: AudioSource, Sendable {
    private static let chunksPerSecond = 20.0

    let fileURL: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    var schedule: ListeningSchedule { .fromLaunch }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AudioChunk.self)
        let playback = Task {
            await play(into: continuation)
        }
        continuation.onTermination = { _ in
            playback.cancel()
        }
        return stream
    }

    @concurrent
    private func play(into continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation) async {
        do {
            let file = try AVAudioFile(forReading: fileURL)
            let format = file.processingFormat
            let capacity = AVAudioFrameCount(format.sampleRate / Self.chunksPerSecond)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
                throw AudioSourceError.audioFileUnreadable
            }
            let clock = ContinuousClock()
            let start = clock.now
            while file.framePosition < file.length {
                try file.read(into: buffer)
                continuation.yield(AudioChunk(buffer))
                try await Task.sleep(until: start + .seconds(Double(file.framePosition) / format.sampleRate))
            }
            continuation.finish()
        } catch is CancellationError {
            continuation.finish()
        } catch {
            logger.error("The audio file could not be read: \(error.localizedDescription)")
            continuation.finish(throwing: AudioSourceError.audioFileUnreadable)
        }
    }
}
#endif
