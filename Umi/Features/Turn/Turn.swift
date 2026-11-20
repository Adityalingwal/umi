import Foundation
import OSLog

final class Turn {
    private let audioSource: any AudioSource
    private let speech: SpeechToText
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

    init(
        audioSource: any AudioSource,
        speech: SpeechToText,
        screen: ScreenCapture,
        brain: any Brain,
        subtitles: Subtitles,
        subtitlePanel: SubtitlePanel,
        cursor: UmiCursor,
        cursorPanel: CursorPanel
    ) {
        self.audioSource = MeteredAudioSource(source: audioSource, cursor: cursor)
        self.speech = speech
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
            logger.notice("Hold cancelled by another key")
        }
    }

    func clearSubtitles() {
        guard subtitles.line != nil else { return }
        answering?.cancel()
        answering = nil
        subtitles.clear()
        logger.notice("Subtitles cleared")
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
        do {
            hearing = try speech.hearing(from: audioSource)
        } catch {
            logger.error("The question stopped: \(Self.reason(for: error), privacy: .public)")
            say(UmiLine.failure(error))
            return
        }
        cursorPanel.startFollowingPointer()
        cursor.listen()
        picture = Task { [screen] in
            try await screen.picture(ofDisplay: pointer.displayID)
        }
        hearing.start()
        self.hearing = hearing
        logger.notice("Hold began")
    }

    private func end() {
        guard let hearing, let picture else {
            cancel()
            return
        }
        self.hearing = nil
        self.picture = nil
        cursor.think()
        logger.notice("Hold ended")
        answering = Task { [weak self] in
            await self?.answer(heardBy: hearing, picture: picture)
        }
    }

    private func answer(heardBy hearing: HoldHearing, picture: Task<ScreenPicture, any Error>) async {
        do {
            let heard = try await hearing.finish()
            guard !Task.isCancelled else { return }
            switch heard {
            case .words(let text):
                logger.notice("Heard \(text.count, privacy: .public) characters")
                try await ask(text, picture: picture)
            case .silence:
                hideCursor()
                logger.notice("Silence: the question ended quietly, Claude not asked")
            case .soundWithoutWords:
                logger.notice("Sound without words: Claude not asked")
                say(UmiLine.couldNotHear)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("The question stopped: \(Self.reason(for: error), privacy: .public)")
            say(UmiLine.failure(error))
        }
    }

    private func ask(_ text: String, picture: Task<ScreenPicture, any Error>) async throws {
        let screenJPEG = try await picture.value.jpegData
        try Task.checkCancellation()
        let question = BrainQuestion(text: text, screenJPEG: screenJPEG)
        var splitter = SentenceSplitter()
        for try await piece in brain.answer(question) {
            splitter.add(piece).forEach(show)
        }
        splitter.flush().map(show)
        guard !Task.isCancelled else { return }
        hideCursor()
        subtitles.finish()
        logger.notice("Answer finished")
    }

    private func show(_ sentence: String) {
        guard !Task.isCancelled else { return }
        hideCursor()
        subtitles.show(sentence)
    }

    private func say(_ line: String) {
        show(line)
        subtitles.finish()
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
