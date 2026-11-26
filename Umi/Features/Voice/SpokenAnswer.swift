import Foundation
import OSLog

final class SpokenAnswer {
    private enum Mode {
        case voiced
        case over
    }

    private static let watchInterval = Duration.milliseconds(100)

    let events: AsyncStream<SpokenEvent>
    private(set) var isSilent = false

    private let eventContinuation: AsyncStream<SpokenEvent>.Continuation
    private let socket: FluxSpeech?
    private let queue: SpeechQueue
    private let player: SpeechPlayer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var mode = Mode.voiced
    private var turns = SpokenTurns()
    private var isTextEnded = false
    private var isAudioComplete = false
    private var openTurnCharacters = 0
    private var silenceRule = SilenceRule()
    private var listening: Task<Void, Never>?
    private var playing: Task<Void, Never>?
    private var watching: Task<Void, Never>?
    private var onFailure: ((SpokenAnswer) -> Void)?
    #if DEBUG
    private var speechFile: SpeechFile?
    #endif

    private init(voiceSocket: FluxSpeech?) {
        let queue = SpeechQueue()
        socket = voiceSocket
        self.queue = queue
        player = SpeechPlayer(queue: queue)
        (events, eventContinuation) = AsyncStream.makeStream(of: SpokenEvent.self)
        if voiceSocket == nil {
            mode = .over
            isSilent = true
            eventContinuation.finish()
        }
    }

    convenience init(socket: FluxSpeech) {
        self.init(voiceSocket: socket)
    }

    // An answer with no voice at all: it takes text and speaks none of it.
    static func silent() -> SpokenAnswer {
        SpokenAnswer(voiceSocket: nil)
    }

    #if DEBUG
    convenience init(socket: FluxSpeech, speechFile: SpeechFile?) {
        self.init(socket: socket)
        self.speechFile = speechFile
        if speechFile != nil {
            queue.recordPlayedSamples()
        }
    }
    #endif

    private var playedMilliseconds: Int {
        queue.playedSamples * 1_000 / Int(SpeechQueue.sampleRate)
    }

    // While an answer's piece is open, a pause of the brain looks like a silent voice.
    private var isSilenceJudged: Bool {
        guard turns.openTurn == nil else { return false }
        return turns.isAudioOwed || queue.hasUnplayedSamples
    }

    func start(onFailure: @escaping (SpokenAnswer) -> Void) {
        guard let socket else { return }
        self.onFailure = onFailure
        silenceRule.startConnecting()
        let messages = socket.messages()
        listening = Task { [weak self] in
            do {
                for try await message in messages {
                    try self?.handle(message)
                }
                self?.connectionEnded()
            } catch {
                self?.fail(error)
            }
        }
        let playback = queue.events
        playing = Task { [weak self] in
            for await event in playback {
                self?.handle(event)
            }
        }
        watchForSilence()
    }

    func stream(_ text: String) {
        guard mode == .voiced else { return }
        if turns.openTurn == nil {
            guard text.contains(where: { !$0.isWhitespace }) else { return }
            let turn = turns.open()
            logger.notice("Piece \(turn, privacy: .public) opened for the answer's text")
        }
        guard send(text) else { return }
        openTurnCharacters += text.unicodeScalars.count
    }

    func speak(_ line: String) {
        guard mode == .voiced else { return }
        closeOpenTurn()
        guard send(line) else { return }
        socket?.flush()
        silenceRule.pieceFlushed()
        let turn = turns.add()
        logger.notice("Piece \(turn, privacy: .public) sent to the voice as one whole line")
    }

    func endText() {
        guard mode == .voiced, !isTextEnded else { return }
        closeOpenTurn()
        isTextEnded = true
        logger.notice("The answer's text ended after \(self.turns.count, privacy: .public) voice pieces")
        endAudioIfComplete()
    }

    func stop() {
        guard mode == .voiced else { return }
        logger.notice("The voice was cut after \(self.playedMilliseconds, privacy: .public) ms of sound")
        end()
        eventContinuation.finish()
    }

    private func send(_ text: String) -> Bool {
        do {
            try socket?.send(text)
            return true
        } catch {
            fail(error)
            return false
        }
    }

    private func closeOpenTurn() {
        guard let turn = turns.close() else { return }
        socket?.flush()
        silenceRule.pieceFlushed()
        let characters = openTurnCharacters
        logger.notice("Piece \(turn, privacy: .public) closed after \(characters, privacy: .public) characters")
        openTurnCharacters = 0
    }

    private func handle(_ message: FluxSpeechMessage) throws {
        guard mode == .voiced else { return }
        switch message {
        case .connected:
            guard silenceRule.connected() else { return }
            logger.notice("The voice connected after the first text was sent to it; the wait for sound starts now")
        case .turnStarted:
            turns.voiceStartedTurn()
        case .audio(let audio):
            let openedTurn = turns.audioArrived()
            queue.append(linear16: audio, startingTurn: openedTurn)
            try player.start()
        case let .turnEnded(billableCharacters, audioMilliseconds):
            let turn = turns.voiceEndedTurn()
            logger.notice(
                """
                Turn \(turn, privacy: .public) audio complete: \
                \(audioMilliseconds, privacy: .public) ms, \(billableCharacters, privacy: .public) billable characters
                """
            )
            queue.turnAudioEnded()
            endAudioIfComplete()
        }
    }

    private func handle(_ event: SpeechQueue.Event) {
        guard mode == .voiced else { return }
        switch event {
        case let .turnStarted(turn, firstSample):
            let lag = Self.milliseconds(since: firstSample)
            logger.notice("Turn \(turn, privacy: .public) started playing, seen \(lag, privacy: .public) ms later")
            turns.startPlaying(turn).forEach { eventContinuation.yield($0) }
        case .playedOut:
            logger.notice("The voice finished playing")
            finish()
        }
    }

    private func watchForSilence() {
        watching = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.watchInterval)
                guard let self, mode == .voiced else { return }
                if let failure = silenceRule.check(isSilenceJudged: isSilenceJudged, played: queue.playedSamples) {
                    fail(failure)
                    return
                }
            }
        }
    }

    private func endAudioIfComplete() {
        guard isTextEnded, !turns.isAudioOwed else { return }
        isAudioComplete = true
        socket?.close()
        if player.isStarted {
            queue.audioEnded()
        } else {
            finish()
        }
    }

    private func connectionEnded() {
        guard !isAudioComplete else { return }
        fail(SpeakingError.connectionEnded)
    }

    private func fail(_ error: any Error) {
        guard mode == .voiced else { return }
        logger.error(
            """
            The voice failed (\(Self.reason(for: error), privacy: .public)) after \
            \(self.playedMilliseconds, privacy: .public) ms of sound; it takes no more text
            """
        )
        isSilent = true
        end()
        eventContinuation.finish()
        onFailure?(self)
    }

    private func finish() {
        end()
        eventContinuation.yield(.finished)
        eventContinuation.finish()
    }

    private func end() {
        mode = .over
        silence()
    }

    private func silence() {
        queue.cut()
        player.stop()
        socket?.close()
        listening?.cancel()
        playing?.cancel()
        watching?.cancel()
        #if DEBUG
        speechFile?.append(queue.takePlayed())
        #endif
    }

    private static func milliseconds(since instant: ContinuousClock.Instant) -> Int {
        Int((instant.duration(to: .now) / .milliseconds(1)).rounded())
    }

    private static func reason(for error: any Error) -> String {
        switch error {
        case let error as SpeakingError: "\(error)"
        case let error as SpeechError: "\(error)"
        default: "unexpected"
        }
    }
}
