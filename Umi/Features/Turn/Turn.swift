import Foundation
import OSLog

final class Turn {
    private let audioSource: any AudioSource
    private let speech: SpeechToText
    private let speaker: Speaker
    private let screen: ScreenCapture
    private let brain: any Brain
    private let subtitles: Subtitles
    private let subtitlePanel: SubtitlePanel
    private let cursor: UmiCursor
    private let cursorPanel: CursorPanel
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var hearing: HoldHearing?
    private var picture: Task<ScreenPicture, any Error>?
    private var answering: Task<Void, Never>?
    private var speaking: SpokenAnswer?

    init(
        audioSource: any AudioSource,
        speech: SpeechToText,
        speaker: Speaker,
        screen: ScreenCapture,
        brain: any Brain,
        subtitles: Subtitles,
        subtitlePanel: SubtitlePanel,
        cursor: UmiCursor,
        cursorPanel: CursorPanel
    ) {
        self.audioSource = MeteredAudioSource(source: audioSource, cursor: cursor)
        self.speech = speech
        self.speaker = speaker
        self.screen = screen
        self.brain = brain
        self.subtitles = subtitles
        self.subtitlePanel = subtitlePanel
        self.cursor = cursor
        self.cursorPanel = cursorPanel
    }

    func handle(_ event: HoldEvent) {
        switch event {
        case .began:
            begin()
        case .ended:
            end()
        case .cancelled:
            cancel()
            subtitles.clear()
            logger.notice("Hold cancelled by another key")
        }
    }

    func escape() {
        guard speaking != nil || subtitles.line != nil else { return }
        cancel()
        subtitles.clear()
        logger.notice("Esc: the question stopped and the subtitles cleared")
    }

    private func begin() {
        cancel()
        subtitles.clear()
        guard let pointer = PointerScreen.current() else {
            logger.error("No screen is under the pointer")
            return
        }
        subtitlePanel.show(on: pointer.screen)
        let hearing: HoldHearing
        let speaking: SpokenAnswer
        do {
            hearing = try speech.hearing(from: audioSource)
            speaking = try speaker.answer()
        } catch {
            stop(because: error)
            return
        }
        self.speaking = speaking
        guard screen.isAllowed else {
            speaking.start()
            stopWithoutScreen(voice: speaking)
            return
        }
        cursorPanel.startFollowingPointer()
        cursor.listen()
        picture = Task { [screen] in
            try await screen.picture(ofDisplay: pointer.displayID)
        }
        hearing.start()
        speaking.start()
        self.hearing = hearing
        logger.notice("Hold began")
    }

    private func end() {
        guard answering == nil, let hearing, let picture, let speaking else { return }
        cursor.think()
        logger.notice("Hold ended")
        answering = Task { [weak self] in
            await self?.answer(heardBy: hearing, picture: picture, voice: speaking)
        }
    }

    private func answer(
        heardBy hearing: HoldHearing,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer
    ) async {
        defer { release(hearing, picture, voice) }
        do {
            let heard = try await hearing.finish()
            guard !Task.isCancelled else { return }
            switch heard {
            case .words(let text):
                logger.notice("Heard \(text.count, privacy: .public) characters")
                try await ask(text, picture: picture, voice: voice)
            case .silence:
                hideCursor()
                logger.notice("Silence: the question ended quietly, Claude not asked")
            case .soundWithoutWords:
                logger.notice("Sound without words: Claude not asked")
                voice.speak(UmiLine.couldNotHear)
                voice.endText()
                await follow(voice)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            stop(because: error, voice: voice)
            await follow(voice)
        }
    }

    private func stopWithoutScreen(voice: SpokenAnswer) {
        answering = Task { [weak self, screen] in
            let refusal = await screen.refusal()
            guard !Task.isCancelled, let self else { return }
            defer { release(voice) }
            stop(because: refusal, voice: voice)
            await follow(voice)
        }
    }

    private func stop(because error: any Error) {
        logger.error("The question stopped: \(Self.reason(for: error), privacy: .public)")
        show(UmiLine.failure(error))
        subtitles.finish()
    }

    private func stop(because error: any Error, voice: SpokenAnswer) {
        logger.error("The question stopped: \(Self.reason(for: error), privacy: .public)")
        let line = UmiLine.failure(error)
        if UmiLine.isSpoken(error) {
            voice.speak(line)
            voice.endText()
        } else {
            voice.stop(showing: line)
        }
    }

    private func ask(_ text: String, picture: Task<ScreenPicture, any Error>, voice: SpokenAnswer) async throws {
        let screenJPEG = try await picture.value.jpegData
        try Task.checkCancellation()
        let answer = brain.answer(BrainQuestion(text: text, screenJPEG: screenJPEG))
        await withDiscardingTaskGroup { group in
            group.addTask { await self.send(answer, to: voice) }
            group.addTask { await self.follow(voice) }
        }
    }

    private func send(_ answer: AsyncThrowingStream<String, any Error>, to voice: SpokenAnswer) async {
        var splitter = SentenceSplitter()
        do {
            for try await piece in answer {
                splitter.add(piece).forEach(voice.speak)
            }
            try Task.checkCancellation()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            stop(because: error, voice: voice)
            return
        }
        splitter.flush().map(voice.speak)
        voice.endText()
    }

    private func follow(_ voice: SpokenAnswer) async {
        for await event in voice.events {
            guard !Task.isCancelled else { return }
            switch event {
            case .show(let text):
                show(text)
            case .finished:
                hideCursor()
                subtitles.finish()
                logger.notice("Answer finished")
            }
        }
    }

    private func show(_ sentence: String) {
        hideCursor()
        subtitles.show(sentence)
    }

    private func release(_ hearing: HoldHearing, _ picture: Task<ScreenPicture, any Error>, _ voice: SpokenAnswer) {
        release(voice)
        if self.hearing === hearing {
            self.hearing = nil
        }
        if self.picture == picture {
            self.picture = nil
        }
    }

    private func release(_ voice: SpokenAnswer) {
        voice.stop()
        if speaking === voice {
            speaking = nil
        }
    }

    private func hideCursor() {
        cursor.hide()
        cursorPanel.stopFollowingPointer()
    }

    private func cancel() {
        answering?.cancel()
        answering = nil
        hearing?.cancel()
        hearing = nil
        picture?.cancel()
        picture = nil
        speaking?.stop()
        speaking = nil
        hideCursor()
    }

    private static func reason(for error: any Error) -> String {
        switch error {
        case let error as SpeechError: "speech: \(error)"
        case let error as AudioSourceError: "audio: \(error)"
        case let error as ScreenError: "screen: \(error)"
        case let error as BrainError: "brain: \(error)"
        default: "unexpected"
        }
    }
}
