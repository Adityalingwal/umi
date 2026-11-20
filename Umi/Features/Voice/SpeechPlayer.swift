import AVFoundation
import OSLog

final class SpeechPlayer {
    private let engine = AVAudioEngine()
    private let queue: SpeechQueue
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    private(set) var isStarted = false

    init(queue: SpeechQueue) {
        self.queue = queue
    }

    func start() throws {
        guard !isStarted else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: SpeechQueue.sampleRate, channels: 1) else {
            throw SpeakingError.playerFailed
        }
        let node = queue.sourceNode(format: format)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            logger.error("The voice's player did not start: \(error.localizedDescription)")
            throw SpeakingError.playerFailed
        }
        isStarted = true
    }

    func stop() {
        engine.stop()
    }
}
