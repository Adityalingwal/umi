#if DEBUG
import Foundation
import OSLog

final class HoldFile: AudioSource {
    private static let pauseBetweenHolds = Duration.seconds(25)

    let holds: AsyncStream<HoldEvent>

    private let fileURLs: [URL]
    private let pauses: [Duration]
    private let holdContinuation: AsyncStream<HoldEvent>.Continuation
    private var playedCount = 0

    var schedule: ListeningSchedule { .fromLaunch }

    private init(fileURLs: [URL], pauses: [Duration] = [pauseBetweenHolds]) {
        self.fileURLs = fileURLs
        self.pauses = pauses.isEmpty ? [Self.pauseBetweenHolds] : pauses
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        if fileURLs.isEmpty {
            holdContinuation.finish()
        } else {
            holdContinuation.yield(.began)
        }
    }

    static func atLaunch(defaults: UserDefaults) -> HoldFile? {
        let paths = list(forKey: "UmiHoldFile", in: defaults)
        guard !paths.isEmpty else { return nil }
        guard paths.count == 1 || !list(forKey: "UmiScreenImage", in: defaults).isEmpty else {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
                .error("Several hold files need -UmiScreenImage, so no hold plays")
            return HoldFile(fileURLs: [])
        }
        let fileURLs = paths.map { URL(filePath: $0) }
        return HoldFile(fileURLs: fileURLs, pauses: pauses(in: defaults))
    }

    private static func list(forKey key: String, in defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: key) ?? defaults.string(forKey: key).map { [$0] } ?? []
    }

    private static func pauses(in defaults: UserDefaults) -> [Duration] {
        list(forKey: "UmiHoldPause", in: defaults).map { text in
            Double(text).flatMap { $0 > 0 ? Duration.seconds($0) : nil } ?? pauseBetweenHolds
        }
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
        try? await Task.sleep(for: pauses[min(playedCount - 1, pauses.count - 1)])
        holdContinuation.yield(.began)
    }
}
#endif
