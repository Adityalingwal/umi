import AVFoundation

nonisolated struct AudioChunk: Sendable {
    let samples: [Float]
    let sampleRate: Double

    init(_ buffer: AVAudioPCMBuffer) {
        sampleRate = buffer.format.sampleRate
        guard let channel = buffer.floatChannelData?[0] else {
            samples = []
            return
        }
        samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
