import Foundation

nonisolated struct HoldRecording: Sendable {
    private static let fullScale = 32_768.0

    private(set) var linear16 = Data()
    private var loudestSample = 0

    var peakLevel: Double {
        Double(loudestSample) / Self.fullScale
    }

    mutating func append(_ audio: Data) {
        linear16.append(audio)
        audio.withUnsafeBytes { bytes in
            for offset in stride(from: 0, to: bytes.count - 1, by: MemoryLayout<Int16>.size) {
                let sample = bytes.loadUnaligned(fromByteOffset: offset, as: Int16.self)
                loudestSample = max(loudestSample, abs(Int(sample)))
            }
        }
    }
}
