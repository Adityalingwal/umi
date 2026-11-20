import Foundation
import OSLog

final class SpokenAnswer {
    private enum Mode {
        case voiced
        case unvoiced
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
    private var sentences: [String] = []
    private var sentencesShown = 0
    private var sentencesStarted = 0
    private var sentencesWithAudio = 0
    private var sentencesEnded = 0
    private var isTextEnded = false
    private var isAudioComplete = false
    private var listening: Task<Void, Never>?
    private var playing: Task<Void, Never>?
    private var watching: Task<Void, Never>?
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

    private var owesSound: Bool {
        sentencesEnded < sentences.count || queue.hasUnplayedSamples
    }

    func start() {
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

    func speak(_ sentence: String) {
        switch mode {
        case .over:
            return
        case .unvoiced:
            sentences.append(sentence)
            sentencesShown = sentences.count
            logger.notice("Sentence \(self.sentences.count - 1, privacy: .public) shows unspoken")
            eventContinuation.yield(.show(sentence))
        case .voiced:
            sentences.append(sentence)
            do {
                try socket.speak(sentence)
            } catch {
                fail(error)
                return
            }
            logger.notice("Sentence \(self.sentences.count - 1, privacy: .public) sent to the voice")
        }
    }

    func endText() {
        guard mode != .over, !isTextEnded else { return }
        isTextEnded = true
        logger.notice("The answer's text ended after \(self.sentences.count, privacy: .public) sentences")
        if mode == .unvoiced {
            finish()
        } else {
            endAudioIfComplete()
        }
    }

    func stop() {
        guard mode != .over else { return }
        if mode == .voiced {
            let playedMilliseconds = queue.playedSamples * 1_000 / Int(SpeechQueue.sampleRate)
            logger.notice("The voice was cut after \(playedMilliseconds, privacy: .public) ms of sound")
        }
        end()
        eventContinuation.finish()
    }

    func stop(showing line: String) {
        guard mode != .over else { return }
        logger.notice("The voice stopped so a line shows unspoken")
        end()
        eventContinuation.yield(.show(line))
        eventContinuation.yield(.finished)
        eventContinuation.finish()
    }

    private func handle(_ message: FluxSpeechMessage) throws {
        guard mode == .voiced else { return }
        switch message {
        case .sentenceStarted:
            sentencesStarted += 1
        case .audio(let audio):
            let isFirstAudio = sentencesWithAudio < sentencesStarted
            sentencesWithAudio = sentencesStarted
            queue.append(linear16: audio, startingSentence: isFirstAudio ? sentencesStarted - 1 : nil)
            try player.start()
        case let .sentenceEnded(billableCharacters, audioMilliseconds):
            logger.notice(
                """
                Sentence \(self.sentencesEnded, privacy: .public) audio complete: \
                \(audioMilliseconds, privacy: .public) ms, \(billableCharacters, privacy: .public) billable characters
                """
            )
            sentencesEnded += 1
            queue.sentenceAudioEnded()
            endAudioIfComplete()
        }
    }

    private func handle(_ event: SpeechQueue.Event) {
        guard mode == .voiced else { return }
        switch event {
        case let .sentenceStarted(index, firstSample):
            guard sentences.indices.contains(index) else { return }
            let lag = Int((firstSample.duration(to: .now) / .milliseconds(1)).rounded())
            logger.notice(
                "Sentence \(index, privacy: .public) started playing \(lag, privacy: .public) ms after its first sample"
            )
            sentencesShown = max(sentencesShown, index + 1)
            eventContinuation.yield(.show(sentences[index]))
        case .playedOut:
            logger.notice("The voice finished playing")
            finish()
        }
    }

    private func watchForSilence() {
        watching = Task { [weak self] in
            var waitingSince: ContinuousClock.Instant?
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
        guard isTextEnded, sentencesEnded == sentences.count else { return }
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
        logger.error("The voice failed (\(Self.reason(for: error), privacy: .public)); the rest shows unspoken")
        silence()
        mode = .unvoiced
        showUnshown()
        if isTextEnded {
            finish()
        }
    }

    private func finish() {
        showUnshown()
        end()
        eventContinuation.yield(.finished)
        eventContinuation.finish()
    }

    private func showUnshown() {
        let unshown = sentences[sentencesShown...]
        sentencesShown = sentences.count
        guard !unshown.isEmpty else { return }
        logger.notice("\(unshown.count, privacy: .public) sentences show together, unspoken")
        eventContinuation.yield(.show(unshown.joined(separator: " ")))
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

    private static func reason(for error: any Error) -> String {
        switch error {
        case let error as SpeakingError: "\(error)"
        case let error as SpeechError: "\(error)"
        default: "unexpected"
        }
    }
}
