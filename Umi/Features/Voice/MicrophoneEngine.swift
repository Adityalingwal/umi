import AVFoundation
import OSLog

nonisolated struct MicrophoneEngine: Sendable {
    private let engine = AVAudioEngine()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")

    @concurrent
    func start(yieldingTo continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation) async {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            logger.error("The microphone has no input format")
            continuation.finish(throwing: AudioSourceError.microphoneUnavailable)
            return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            continuation.yield(AudioChunk(buffer))
        }
        do {
            try engine.start()
        } catch {
            logger.error("The microphone did not start: \(error.localizedDescription)")
            continuation.finish(throwing: AudioSourceError.microphoneUnavailable)
            return
        }
        if Task.isCancelled {
            stop()
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}
