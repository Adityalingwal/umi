import AVFoundation
import Synchronization

nonisolated final class SpeechQueue: Sendable {
    enum Event: Sendable {
        case turnStarted(Int, playedAt: ContinuousClock.Instant)
        case turnEnded(Int)
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

    func millisecondsBeforeTurn(_ turn: Int) -> Int? {
        state.withLock { $0.samplesBeforeTurn(turn) }.map { $0 * 1_000 / Int(Self.sampleRate) }
    }

    func turnAudioEnded(_ turn: Int) {
        state.withLock { $0.turnAudioEnded(turn) }
    }

    func audioEnded() {
        state.withLock { $0.isAudioComplete = true }
    }

    func cut() {
        state.withLock { $0.cut() }
        eventContinuation.finish()
    }

    func cutReturningUnfinishedTurn() -> Int? {
        let turn = state.withLock { state in
            defer { state.cut() }
            return state.unfinishedTurn
        }
        eventContinuation.finish()
        return turn
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
    private var turnEnds: [(sample: Int, turn: Int)] = []
    private var nextTurnEnd = 0
    private var oddByte: UInt8?
    private var wholeTurnsEnd = 0
    private var isPlaying = false
    private var isPlayedOut = false
    private var isCut = false

    var hasUnplayedSamples: Bool {
        !isCut && played < samples.count
    }

    var unfinishedTurn: Int? {
        guard !isCut, nextTurnStart > 0 else { return nil }
        let end = nextTurnStart < turnStarts.count ? turnStarts[nextTurnStart].sample : samples.count
        return played < end ? turnStarts[nextTurnStart - 1].turn : nil
    }

    func samplesBeforeTurn(_ turn: Int) -> Int? {
        guard !isCut, let start = turnStarts.last(where: { $0.turn == turn })?.sample, start >= played else {
            return nil
        }
        return start - played
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

    mutating func turnAudioEnded(_ turn: Int) {
        wholeTurnsEnd = samples.count
        turnEnds.append((samples.count, turn))
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
            postTurnEnds(into: &events)
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
        postTurnEnds(into: &events)
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

    private var hasTurnEndDue: Bool {
        !isCut && nextTurnEnd < turnEnds.count && turnEnds[nextTurnEnd].sample <= played
    }

    private mutating func postTurnEnds(into events: inout [SpeechQueue.Event]) {
        while hasTurnEndDue {
            events.append(.turnEnded(turnEnds[nextTurnEnd].turn))
            nextTurnEnd += 1
        }
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
