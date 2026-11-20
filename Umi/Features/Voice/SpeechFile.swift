#if DEBUG
import AVFoundation
import OSLog

final class SpeechFile {
    private let fileURL: URL
    private var samples: [Float] = []
    private var writing: Task<Void, Never>?

    private init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func atLaunch(defaults: UserDefaults) -> SpeechFile? {
        defaults.string(forKey: "UmiSpeechFile").map { SpeechFile(fileURL: URL(filePath: $0)) }
    }

    func append(_ played: [Float]) {
        guard !played.isEmpty else { return }
        samples += played
        let everything = samples
        let fileURL = fileURL
        let previous = writing
        writing = Task {
            await previous?.value
            await Self.write(everything, to: fileURL)
        }
    }

    @concurrent
    private static func write(_ samples: [Float], to fileURL: URL) async {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: SpeechQueue.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else {
            logger.error("The speech file could not be prepared")
            return
        }
        samples.withUnsafeBufferPointer { played in
            guard let base = played.baseAddress else { return }
            channel.update(from: base, count: played.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: SpeechQueue.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        do {
            let file = try AVAudioFile(
                forWriting: fileURL,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            try file.write(from: buffer)
            logger.notice("The speech file now holds \(samples.count, privacy: .public) samples")
        } catch {
            logger.error("The speech file could not be written: \(error.localizedDescription)")
        }
    }
}
#endif
