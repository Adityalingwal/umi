import Foundation
import OSLog

final class SpokenAnswer {
    private enum Mode {
        case voiced
        case over
    }

    // Aditya's pick from #14's measurements, where the first sound came at most 1.22 s after its sentence's Flush.
    private static let waitingLimit = Duration.seconds(3)
    private static let watchInterval = Duration.milliseconds(100)

    let events: AsyncStream<SpokenEvent>

    private let eventContinuation: AsyncStream<SpokenEvent>.Continuation
    private let socket: FluxSpeech
    private let queue: SpeechQueue
    private let player: SpeechPlayer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var mode = Mode.voiced
    private var turns = SpokenTurns()
    private var isTextEnded = false
    private var isAudioComplete = false
    private var waitingSince: ContinuousClock.Instant?
    private var listening: Task<Void, Never>?
    private var playing: Task<Void, Never>?
    private var watching: Task<Void, Never>?
    private var onFailure: ((SpokenAnswer) -> Void)?
    #if DEBUG
    private var speechFile: SpeechFile?
    #endif

    init(socket: FluxSpeech) {
        let queue = SpeechQueue()
        self.socket = socket
        self.queue = queue
        player = SpeechPlayer(queue: queue)
        (events, eventContinuation) = AsyncStream.makeStream(of: SpokenEvent.self)
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

    var isSpeaking: Bool { mode == .voiced }

    private var playedMilliseconds: Int {
        queue.playedSamples * 1_000 / Int(SpeechQueue.sampleRate)
    }

    private var owesSound: Bool {
        turns.isAudioOwed || queue.hasUnplayedSamples
    }

    func start(onFailure: @escaping (SpokenAnswer) -> Void) {
        self.onFailure = onFailure
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

    func speak(_ sentence: String, nameStart: String.Index? = nil) {
        guard mode == .voiced else { return }
        let firstTurn = turns.count
        let parts = turns.add(sentence, nameStart: nameStart)
        do {
            try parts.forEach(socket.speak)
        } catch {
            fail(error)
            return
        }
        logger.notice(
            """
            Sentence \(self.turns.sentences.count - 1, privacy: .public) sent to the voice as \
            \(parts.count, privacy: .public) turns from turn \(firstTurn, privacy: .public)
            """
        )
    }

    func endText() {
        guard mode == .voiced, !isTextEnded else { return }
        isTextEnded = true
        logger.notice("The answer's text ended after \(self.turns.sentences.count, privacy: .public) sentences")
        endAudioIfComplete()
    }

    func stop() {
        guard mode == .voiced else { return }
        logger.notice("The voice was cut after \(self.playedMilliseconds, privacy: .public) ms of sound")
        end()
        eventContinuation.finish()
    }

    private func handle(_ message: FluxSpeechMessage) throws {
        guard mode == .voiced else { return }
        switch message {
        case .connected:
            guard waitingSince != nil else { return }
            waitingSince = .now
            logger.notice("The voice connected after its first sentence was ready; the wait for sound starts now")
        case .turnStarted:
            turns.voiceStartedTurn()
        case .audio(let audio):
            let openedTurn = turns.audioArrived()
            queue.append(linear16: audio, startingTurn: openedTurn)
            try player.start()
            if let openedTurn, turns.isName(openedTurn), let wait = queue.millisecondsBeforeTurn(openedTurn) {
                logger.notice("The name's audio arrived; it plays in \(wait, privacy: .public) ms")
                eventContinuation.yield(.nameComing(after: .milliseconds(wait)))
            }
        case let .turnEnded(billableCharacters, audioMilliseconds):
            let turn = turns.voiceEndedTurn()
            logger.notice(
                """
                Turn \(turn, privacy: .public) audio complete: \
                \(audioMilliseconds, privacy: .public) ms, \(billableCharacters, privacy: .public) billable characters
                """
            )
            queue.turnAudioEnded(turn)
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
        case .turnEnded(let turn):
            guard turns.endsNameLine(turn) else { return }
            logger.notice("The line that names the target finished playing")
            eventContinuation.yield(.nameLineEnded)
        case .playedOut:
            logger.notice("The voice finished playing")
            finish()
        }
    }

    private func watchForSilence() {
        watching = Task { [weak self] in
            var lastPlayed = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.watchInterval)
                guard let self, mode == .voiced else { return }
                let played = queue.playedSamples
                if !owesSound {
                    waitingSince = nil
                } else if let since = waitingSince, played == lastPlayed {
                    if since.duration(to: .now) >= Self.waitingLimit {
                        fail(SpeakingError.noSound)
                        return
                    }
                } else {
                    waitingSince = .now
                }
                lastPlayed = played
            }
        }
    }

    private func endAudioIfComplete() {
        guard isTextEnded, !turns.isAudioOwed else { return }
        isAudioComplete = true
        socket.close()
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
        socket.close()
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
