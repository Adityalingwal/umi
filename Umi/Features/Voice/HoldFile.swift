#if DEBUG
import Foundation

struct HoldFile: AudioSource {
    let holds: AsyncStream<HoldEvent>

    private let playback: AudioFileSource
    private let holdContinuation: AsyncStream<HoldEvent>.Continuation

    var schedule: ListeningSchedule { .fromLaunch }

    private init(fileURL: URL) {
        playback = AudioFileSource(fileURL: fileURL)
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        holdContinuation.yield(.began)
    }

    static func atLaunch(defaults: UserDefaults) -> HoldFile? {
        defaults.string(forKey: "UmiHoldFile").map { HoldFile(fileURL: URL(filePath: $0)) }
    }

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AudioChunk.self)
        let fileChunks = playback.chunks()
        let holdContinuation = holdContinuation
        let forwarding = Task {
            var failure: (any Error)?
            do {
                for try await chunk in fileChunks {
                    continuation.yield(chunk)
                }
            } catch {
                failure = error
            }
            if !Task.isCancelled {
                holdContinuation.yield(.ended)
            }
            holdContinuation.finish()
            continuation.finish(throwing: failure)
        }
        continuation.onTermination = { _ in
            forwarding.cancel()
        }
        return stream
    }
}
#endif
