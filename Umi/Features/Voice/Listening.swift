import Foundation
import Observation
import OSLog

@Observable
final class Listening {
    private(set) var state = ListeningState.resting

    @ObservationIgnored private let source: any AudioSource
    @ObservationIgnored private var hearing: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Umi",
        category: "Voice"
    )

    init(source: any AudioSource) {
        self.source = source
    }

    static func atLaunch(defaults: UserDefaults) -> Listening {
        #if DEBUG
        if let path = defaults.string(forKey: "UmiAudioFile") {
            return Listening(source: AudioFileSource(fileURL: URL(filePath: path)))
        }
        #endif
        return Listening(source: MicrophoneSource(permission: MicrophonePermission()))
    }

    func appDidLaunch() {
        if source.schedule == .fromLaunch {
            listen()
        }
    }

    func menuDidOpen() {
        if source.schedule == .whileMenuIsOpen {
            listen()
        }
    }

    func menuDidClose() {
        if source.schedule == .whileMenuIsOpen {
            stop()
        }
    }

    private func listen() {
        hearing?.cancel()
        let chunks = source.chunks()
        logger.notice("Listening started")
        hearing = Task { [weak self] in
            do {
                for try await chunk in chunks {
                    self?.state = .hearing(AudioLevel(chunk))
                }
                guard !Task.isCancelled else { return }
                self?.finish()
            } catch is CancellationError {
                return
            } catch let failure as AudioSourceError {
                self?.fail(failure)
            } catch {
                self?.logger.error("Listening failed: \(error.localizedDescription)")
                self?.finish()
            }
        }
    }

    private func stop() {
        hearing?.cancel()
        hearing = nil
        state = .resting
        logger.notice("Listening stopped")
    }

    private func finish() {
        hearing = nil
        state = .resting
        logger.notice("Listening ended")
    }

    private func fail(_ failure: AudioSourceError) {
        hearing = nil
        state = .failed(failure)
        logger.notice("Listening failed: \(String(describing: failure), privacy: .public)")
    }
}
