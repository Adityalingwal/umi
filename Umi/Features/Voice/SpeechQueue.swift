import AVFoundation
import Synchronization

nonisolated final class SpeechQueue: Sendable {
    enum Event: Sendable {
        case sentenceStarted(Int, playedAt: ContinuousClock.Instant)
        case playedOut
    }

    static let sampleRate = 24_000.0
    // #14 measured a stutter at the start of most answers; 250 ms in hand removed it.
    fileprivate static let samplesBeforePlaying = Int(sampleRate / 4)

    let events: AsyncStream<Event>

    private let eventContinuation: AsyncStream<Event>.Continuation
    private let state = Mutex(QueueState())

    init() {
        (events, eventContinuation) = AsyncStream.makeStream(of: Event.self)
    }

    var playedSamples: Int {
        state.withLock { $0.played }
    }

    func append(linear16 audio: Data, startingSentence sentence: Int?) {
        state.withLock { $0.append(linear16: audio, startingSentence: sentence) }
    }

    func sentenceAudioEnded() {
        state.withLock { $0.hasWholeSentence = true }
    }

    func audioEnded() {
        state.withLock { $0.isAudioComplete = true }
    }

    func cut() {
        state.withLock { $0.cut() }
        eventContinuation.finish()
    }

    func sourceNode(format: AVAudioFormat) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { [self] _, _, frameCount, bufferList in
            render(Int(frameCount), into: bufferList)
            return noErr
        }
    }

    private func render(_ frameCount: Int, into bufferList: UnsafeMutablePointer<AudioBufferList>) {
        guard let data = UnsafeMutableAudioBufferListPointer(bufferList).first?.mData else { return }
        let output = data.assumingMemoryBound(to: Float.self)
        let now = ContinuousClock.now
        let events = state.withLock { $0.render(frameCount, into: output, at: now) }
        events.forEach { eventContinuation.yield($0) }
    }
}

private nonisolated struct QueueState {
    var played = 0
    var hasWholeSentence = false
    var isAudioComplete = false

    private var samples: [Float] = []
    private var sentenceStarts: [(sample: Int, sentence: Int)] = []
    private var nextSentenceStart = 0
    private var oddByte: UInt8?
    private var isPlaying = false
    private var isPlayedOut = false
    private var isCut = false

    mutating func append(linear16 audio: Data, startingSentence sentence: Int?) {
        guard !isCut else { return }
        if let sentence {
            sentenceStarts.append((samples.count, sentence))
        }
        var bytes = [UInt8](audio)
        if let oddByte {
            bytes.insert(oddByte, at: 0)
        }
        oddByte = bytes.count.isMultiple(of: 2) ? nil : bytes.removeLast()
        for index in stride(from: 0, to: bytes.count, by: 2) {
            let sample = Int16(bitPattern: UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8)
            samples.append(Float(sample) / 32_768)
        }
    }

    mutating func cut() {
        isCut = true
        samples = []
    }

    mutating func render(
        _ frameCount: Int,
        into output: UnsafeMutablePointer<Float>,
        at now: ContinuousClock.Instant
    ) -> [SpeechQueue.Event] {
        var events: [SpeechQueue.Event] = []
        startIfReady()
        for frame in 0..<frameCount {
            guard isPlaying, !isCut, played < samples.count else {
                output[frame] = 0
                continue
            }
            if nextSentenceStart < sentenceStarts.count, sentenceStarts[nextSentenceStart].sample == played {
                let offset = Duration.seconds(Double(frame) / SpeechQueue.sampleRate)
                events.append(.sentenceStarted(sentenceStarts[nextSentenceStart].sentence, playedAt: now + offset))
                nextSentenceStart += 1
            }
            output[frame] = samples[played]
            played += 1
        }
        if isPlaying, isAudioComplete, !isCut, !isPlayedOut, played == samples.count {
            isPlayedOut = true
            events.append(.playedOut)
        }
        return events
    }

    private mutating func startIfReady() {
        guard !isPlaying, !isCut, played < samples.count else { return }
        isPlaying = samples.count - played >= SpeechQueue.samplesBeforePlaying || hasWholeSentence || isAudioComplete
    }
}
