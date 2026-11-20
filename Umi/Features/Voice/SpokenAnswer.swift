import Foundation
import OSLog

final class SpokenAnswer {
    let events: AsyncThrowingStream<SpokenEvent, any Error>

    private let eventContinuation: AsyncThrowingStream<SpokenEvent, any Error>.Continuation
    private let socket: FluxSpeech
    private let queue: SpeechQueue
    private let player: SpeechPlayer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var sentences: [String] = []
    private var sentencesStarted = 0
    private var sentencesWithAudio = 0
    private var sentencesEnded = 0
    private var isTextEnded = false
    private var isOver = false
    private var listening: Task<Void, Never>?
    private var playing: Task<Void, Never>?
    #if DEBUG
    private var speechFile: SpeechFile?
    #endif

    init(socket: FluxSpeech) {
        let queue = SpeechQueue()
        self.socket = socket
        self.queue = queue
        player = SpeechPlayer(queue: queue)
        (events, eventContinuation) = AsyncThrowingStream.makeStream(of: SpokenEvent.self)
    }

    #if DEBUG
    convenience init(socket: FluxSpeech, speechFile: SpeechFile?) {
        self.init(socket: socket)
        self.speechFile = speechFile
    }
    #endif

    func start() {
        let messages = socket.messages()
        listening = Task { [weak self] in
            do {
                for try await message in messages {
                    try self?.handle(message)
                }
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
    }

    func speak(_ sentence: String) {
        guard !isOver else { return }
        sentences.append(sentence)
        socket.speak(sentence)
        logger.notice("Sentence \(self.sentences.count - 1, privacy: .public) sent to the voice")
    }

    func endText() {
        guard !isOver else { return }
        isTextEnded = true
        logger.notice("The answer's text ended after \(self.sentences.count, privacy: .public) sentences")
        endAudioIfComplete()
    }

    func stop() {
        guard !isOver else { return }
        queue.cut()
        let playedMilliseconds = queue.playedSamples * 1_000 / Int(SpeechQueue.sampleRate)
        logger.notice("The voice was cut after \(playedMilliseconds, privacy: .public) ms of sound")
        end()
        eventContinuation.finish()
    }

    private func handle(_ message: FluxSpeechMessage) throws {
        guard !isOver else { return }
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
        guard !isOver else { return }
        switch event {
        case let .sentenceStarted(index, firstSample):
            guard sentences.indices.contains(index) else { return }
            let lag = Int((firstSample.duration(to: .now) / .milliseconds(1)).rounded())
            logger.notice(
                "Sentence \(index, privacy: .public) started playing \(lag, privacy: .public) ms after its first sample"
            )
            eventContinuation.yield(.sentenceStarted(sentences[index]))
        case .playedOut:
            logger.notice("The voice finished playing")
            finish()
        }
    }

    private func endAudioIfComplete() {
        guard isTextEnded, sentencesEnded == sentences.count else { return }
        socket.close()
        if player.isStarted {
            queue.audioEnded()
        } else {
            finish()
        }
    }

    private func finish() {
        end()
        eventContinuation.yield(.finished)
        eventContinuation.finish()
    }

    private func fail(_ error: any Error) {
        guard !isOver else { return }
        queue.cut()
        end()
        eventContinuation.finish(throwing: error)
    }

    private func end() {
        isOver = true
        player.stop()
        socket.close()
        listening?.cancel()
        playing?.cancel()
        #if DEBUG
        speechFile?.append(queue.takePlayed())
        #endif
    }
}
