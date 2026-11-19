import AVFoundation
import OSLog

final class SpeechAudioConverter {
    static let sampleRate = 16_000.0

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var converter: AVAudioConverter?

    func linear16(from chunk: AudioChunk) -> Data {
        guard !chunk.samples.isEmpty,
              let converter = converter(forInputRate: chunk.sampleRate),
              let input = inputBuffer(for: chunk, format: converter.inputFormat) else {
            return Data()
        }
        let ratio = Self.sampleRate / chunk.sampleRate
        let capacity = AVAudioFrameCount(Double(chunk.samples.count) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            return Data()
        }
        var isInputUsed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            if isInputUsed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            isInputUsed = true
            inputStatus.pointee = .haveData
            return input
        }
        guard status != .error, let samples = output.int16ChannelData?[0] else {
            logger.error("Audio conversion failed: \(conversionError?.localizedDescription ?? "unknown")")
            return Data()
        }
        return Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
    }

    private func converter(forInputRate rate: Double) -> AVAudioConverter? {
        if let converter, converter.inputFormat.sampleRate == rate {
            return converter
        }
        guard let input = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let output = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Self.sampleRate,
                channels: 1,
                interleaved: true
              ) else {
            return nil
        }
        converter = AVAudioConverter(from: input, to: output)
        return converter
    }

    private func inputBuffer(for chunk: AudioChunk, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let count = AVAudioFrameCount(chunk.samples.count)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }
        chunk.samples.withUnsafeBufferPointer { samples in
            guard let base = samples.baseAddress else { return }
            channel.update(from: base, count: samples.count)
        }
        buffer.frameLength = count
        return buffer
    }
}
