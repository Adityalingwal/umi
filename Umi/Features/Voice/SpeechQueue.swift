import AVFoundation
import Synchronization

nonisolated final class SpeechQueue: Sendable {
    enum Event: Sendable {
        case turnStarted(Int, playedAt: ContinuousClock.Instant)
        case playedOut
    }

    static let sampleRate = 24_000.0
    // #14 measured a stutter when audio plays the moment it arrives; 250 ms in hand removed it.
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

    var hasUnplayedSamples: Bool {
        state.withLock { $0.hasUnplayedSamples }
    }

    func append(linear16 audio: Data, startingTurn turn: Int?) {
        state.withLock { $0.append(linear16: audio, startingTurn: turn) }
    }

    func turnAudioEnded() {
        state.withLock { $0.turnAudioEnded() }
    }

    func audioEnded() {
        state.withLock { $0.isAudioComplete = true }
    }

    func cut() {
        state.withLock { $0.cut() }
        eventContinuation.finish()
    }

    #if DEBUG
    func recordPlayedSamples() {
        state.withLock { $0.isRecording = true }
    }

    func takePlayed() -> [Float] {
        state.withLock { state in
            defer { state.record = [] }
            return state.record
        }
    }
    #endif

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
    var isAudioComplete = false
    #if DEBUG
    var isRecording = false
    var record: [Float] = []
    #endif

    private var samples: [Float] = []
    private var turnStarts: [(sample: Int, turn: Int)] = []
    private var nextTurnStart = 0
    private var oddByte: UInt8?
    private var wholeTurnsEnd = 0
    private var isPlaying = false
    private var isPlayedOut = false
    private var isCut = false

    var hasUnplayedSamples: Bool {
        !isCut && played < samples.count
    }

    mutating func append(linear16 audio: Data, startingTurn turn: Int?) {
        guard !isCut else { return }
        if let turn {
            turnStarts.append((samples.count, turn))
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

    mutating func turnAudioEnded() {
        wholeTurnsEnd = samples.count
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
            if nextTurnStart < turnStarts.count, turnStarts[nextTurnStart].sample == played {
                let playedAt = Self.time(ofFrame: frame, after: now)
                events.append(.turnStarted(turnStarts[nextTurnStart].turn, playedAt: playedAt))
                nextTurnStart += 1
            }
            output[frame] = samples[played]
            played += 1
        }
        #if DEBUG
        if isRecording, isPlaying, !isCut, !isPlayedOut {
            record.append(contentsOf: UnsafeBufferPointer(start: output, count: frameCount))
        }
        #endif
        if isAudioComplete, !isCut, !isPlayedOut, played == samples.count {
            isPlayedOut = true
            events.append(.playedOut)
        }
        if isPlaying, !isAudioComplete, played == samples.count {
            isPlaying = false
        }
        return events
    }

    private static func time(ofFrame frame: Int, after start: ContinuousClock.Instant) -> ContinuousClock.Instant {
        start + Duration.seconds(Double(frame) / SpeechQueue.sampleRate)
    }

    private mutating func startIfReady() {
        guard !isPlaying, !isCut, played < samples.count else { return }
        isPlaying = samples.count - played >= SpeechQueue.samplesBeforePlaying || wholeTurnsEnd > played
            || isAudioComplete
    }
}
