import Foundation
import OSLog

final class Turn {
    private let audioSource: any AudioSource
    private let deepgramKey: DeepgramKey?
    private let urlSession: URLSession
    private let screen: ScreenCapture
    private let brain: any Brain
    private let subtitles: Subtitles
    private let subtitlePanel: SubtitlePanel
    private let cursor: UmiCursor
    private let cursorPanel: CursorPanel
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var transcription: FluxTranscription?
    private var picture: Task<ScreenPicture, any Error>?
    private var answering: Task<Void, Never>?

    init(
        audioSource: any AudioSource,
        deepgramKey: DeepgramKey?,
        urlSession: URLSession,
        screen: ScreenCapture,
        brain: any Brain,
        subtitles: Subtitles,
        subtitlePanel: SubtitlePanel,
        cursor: UmiCursor,
        cursorPanel: CursorPanel
    ) {
        self.audioSource = MeteredAudioSource(source: audioSource, cursor: cursor)
        self.deepgramKey = deepgramKey
        self.urlSession = urlSession
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
        guard let deepgramKey else {
            logger.error("The Deepgram key is missing")
            return
        }
        guard let pointer = PointerScreen.current() else {
            logger.error("No screen is under the pointer")
            return
        }
        subtitlePanel.show(on: pointer.screen)
        cursorPanel.startFollowingPointer()
        cursor.listen()
        picture = Task { [screen] in
            try await screen.picture(ofDisplay: pointer.displayID)
        }
        let transcription = FluxTranscription(key: deepgramKey, source: audioSource, session: urlSession)
        transcription.start()
        self.transcription = transcription
        logger.notice("Hold began")
    }

    private func end() {
        guard let transcription, let picture else {
            cancel()
            return
        }
        self.transcription = nil
        self.picture = nil
        cursor.think()
        logger.notice("Hold ended")
        answering = Task { [weak self] in
            await self?.answer(heardBy: transcription, picture: picture)
        }
    }

    private func answer(heardBy transcription: FluxTranscription, picture: Task<ScreenPicture, any Error>) async {
        do {
            let text = try await transcription.finish()
            guard !Task.isCancelled else { return }
            guard !text.isEmpty else {
                hideCursor()
                logger.notice("Nothing was heard")
                return
            }
            logger.notice("Heard \(text.count, privacy: .public) characters")
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
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            hideCursor()
            logger.error("The question stopped: \(Self.reason(for: error), privacy: .public)")
        }
    }

    private func show(_ sentence: String) {
        guard !Task.isCancelled else { return }
        hideCursor()
        subtitles.show(sentence)
    }

    private func hideCursor() {
        cursor.hide()
        cursorPanel.stopFollowingPointer()
    }

    private func cancel() {
        answering?.cancel()
        answering = nil
        transcription?.cancel()
        transcription = nil
        picture?.cancel()
        picture = nil
        hideCursor()
    }

    private static func reason(for error: any Error) -> String {
        switch error {
        case let error as SpeechError: "speech: \(error)"
        case let error as ScreenError: "screen: \(error)"
        case let error as BrainError: "brain: \(error)"
        default: "unexpected"
        }
    }
}
