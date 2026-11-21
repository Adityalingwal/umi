#if DEBUG
import Foundation
import OSLog

final class HoldFile: AudioSource {
    private static let pauseBetweenHolds = Duration.seconds(25)

    let holds: AsyncStream<HoldEvent>

    private let fileURLs: [URL]
    private let holdContinuation: AsyncStream<HoldEvent>.Continuation
    private var playedCount = 0

    var schedule: ListeningSchedule { .fromLaunch }

    private init(fileURLs: [URL]) {
        self.fileURLs = fileURLs
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        if fileURLs.isEmpty {
            holdContinuation.finish()
        } else {
            holdContinuation.yield(.began)
        }
    }

    static func atLaunch(defaults: UserDefaults) -> HoldFile? {
        let key = "UmiHoldFile"
        let paths = defaults.stringArray(forKey: key) ?? defaults.string(forKey: key).map { [$0] } ?? []
        guard !paths.isEmpty else { return nil }
        guard paths.count == 1 || defaults.string(forKey: "UmiScreenImage") != nil else {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
                .error("Several hold files need -UmiScreenImage, so no hold plays")
            return HoldFile(fileURLs: [])
        }
        return HoldFile(fileURLs: paths.map { URL(filePath: $0) })
    }

    func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: AudioChunk.self)
        guard playedCount < fileURLs.count else {
            continuation.finish()
            return stream
        }
        let fileChunks = AudioFileSource(fileURL: fileURLs[playedCount]).chunks()
        playedCount += 1
        let forwarding = Task { [weak self] in
            var failure: (any Error)?
            do {
                for try await chunk in fileChunks {
                    continuation.yield(chunk)
                }
            } catch {
                failure = error
            }
            guard !Task.isCancelled else {
                self?.holdContinuation.finish()
                continuation.finish(throwing: failure)
                return
            }
            self?.holdContinuation.yield(.ended)
            continuation.finish(throwing: failure)
            await self?.beginNextHold()
        }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                forwarding.cancel()
            }
        }
        return stream
    }

    private func beginNextHold() async {
        guard playedCount < fileURLs.count else {
            holdContinuation.finish()
            return
        }
        try? await Task.sleep(for: Self.pauseBetweenHolds)
        holdContinuation.yield(.began)
    }
}
#endif
