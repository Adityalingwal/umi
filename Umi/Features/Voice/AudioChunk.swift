import AVFoundation

nonisolated struct AudioChunk: Sendable {
    let samples: [Float]

    init(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else {
            samples = []
            return
        }
        samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}
