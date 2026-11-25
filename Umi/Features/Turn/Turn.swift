import AppKit
import OSLog

final class Turn {
    private let audioSource: any AudioSource
    private let speech: SpeechToText
    private let speaker: Speaker
    private let screen: ScreenCapture
    private let brain: any Brain
    private let conversation: Conversation
    private let cursorStage: CursorStage
    private let pointer: Pointer
    private let board: Board
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var hearing: HoldHearing?
    private var picture: Task<ScreenPicture, any Error>?
    private var answering: Task<Void, Never>?
    private var speaking: SpokenAnswer?
    private var pointing: Pointing?
    private lazy var follower = VoiceFollower(board: board) { [cursorStage] in
        cursorStage.hide()
    }

    init(
        audioSource: any AudioSource,
        speech: SpeechToText,
        speaker: Speaker,
        screen: ScreenCapture,
        brain: any Brain,
        conversation: Conversation,
        cursor: UmiCursor,
        cursorPanel: CursorPanel,
        pointer: Pointer,
        board: Board
    ) {
        self.audioSource = MeteredAudioSource(source: audioSource, cursor: cursor)
        self.speech = speech
        self.speaker = speaker
        self.screen = screen
        self.brain = brain
        self.conversation = conversation
        cursorStage = CursorStage(cursor: cursor, panel: cursorPanel)
        self.pointer = pointer
        self.board = board
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

    func escape() {
        guard speaking != nil || pointing?.isShowing == true || board.isDrawing || cursorStage.isFailed else { return }
        cancel()
        logger.notice("Esc: the question stopped")
    }

    private func begin() {
        cancel()
        guard let underPointer = PointerScreen.current() else {
            logger.error("No screen is under the pointer")
            return
        }
        let hearing: HoldHearing
        let speaking: SpokenAnswer
        do {
            hearing = try speech.hearing(from: audioSource)
            speaking = try speaker.answer()
        } catch {
            fail(because: error)
            return
        }
        self.speaking = speaking
        guard screen.isAllowed else {
            start(speaking)
            stopWithoutScreen(voice: speaking)
            return
        }
        pointing = pointer.pointing(
            on: underPointer.screen.frame,
            cursorRest: { [cursorStage] in cursorStage.restBesidePointer },
            onDepart: { [cursorStage] in cursorStage.hide() }
        )
        cursorStage.listen()
        picture = Task { [screen] in
            try await screen.picture(ofDisplay: underPointer.displayID)
        }
        hearing.start()
        start(speaking)
        self.hearing = hearing
        logger.notice("Hold began")
    }

    private func end() {
        guard answering == nil, let hearing, let picture, let speaking else { return }
        cursorStage.think()
        logger.notice("Hold ended")
        let pointing = pointing
        answering = Task { [weak self] in
            await self?.answer(heardBy: hearing, picture: picture, voice: speaking, pointing: pointing)
        }
    }

    private func answer(
        heardBy hearing: HoldHearing,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer,
        pointing: Pointing?
    ) async {
        defer { release(hearing, picture, voice) }
        do {
            let heard = try await hearing.finish()
            guard !Task.isCancelled else { return }
            switch heard {
            case .words(let text):
                logger.notice("Heard \(text.count, privacy: .public) characters")
                try await ask(text, picture: picture, voice: voice, pointing: pointing)
            case .silence:
                cursorStage.hide()
                pointing?.answerEnded()
                logger.notice("Silence: the question ended quietly, the brain not asked")
            case .soundWithoutWords:
                logger.notice("Sound without words: the brain not asked")
                voice.speak(UmiLine.couldNotHear)
                voice.endText()
                await follower.follow(voice, pointing: pointing)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            stop(because: error, voice: voice)
            await follower.follow(voice, pointing: pointing)
        }
    }

    private func stopWithoutScreen(voice: SpokenAnswer) {
        answering = Task { [weak self, screen] in
            let refusal = await screen.refusal()
            guard !Task.isCancelled, let self else { return }
            defer { release(voice) }
            stop(because: refusal, voice: voice)
            await follower.follow(voice, pointing: nil)
        }
    }

    private func start(_ voice: SpokenAnswer) {
        voice.start { [weak self] voice in
            self?.voiceFailed(voice)
        }
    }

    private func voiceFailed(_ voice: SpokenAnswer) {
        guard speaking === voice else { return }
        logger.error("The question failed: the voice could not speak")
        failAnswer()
    }

    private func stop(because error: any Error, voice: SpokenAnswer) {
        guard let line = UmiLine.failure(error) else {
            fail(because: error)
            return
        }
        logger.error("The question stopped: \(StopReason.text(for: error), privacy: .public)")
        voice.speak(line)
        voice.endText()
    }

    private func fail(because error: any Error) {
        logger.error("The question failed with no line to speak: \(StopReason.text(for: error), privacy: .public)")
        failAnswer()
    }

    private func failAnswer() {
        cancel()
        cursorStage.fail()
    }

    private func ask(
        _ text: String,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer,
        pointing: Pointing?
    ) async throws {
        let screen = try await picture.value
        try Task.checkCancellation()
        let question = BrainQuestion(
            text: text,
            screenJPEG: screen.jpegData,
            screenWidth: screen.width,
            screenHeight: screen.height,
            earlierExchanges: conversation.exchanges,
            boardBrief: board.brief
        )
        let answer = brain.answer(question)
        await withDiscardingTaskGroup { group in
            group.addTask { await self.send(answer, for: text, to: voice, pointing: pointing, on: screen) }
            group.addTask { await self.follower.follow(voice, pointing: pointing) }
        }
    }

    private func send(
        _ answer: AsyncThrowingStream<String, any Error>,
        for question: String,
        to voice: SpokenAnswer,
        pointing: Pointing?,
        on picture: ScreenPicture
    ) async {
        var reader = AnswerReader(voice: voice, pointing: pointing, picture: picture, board: board)
        defer { conversation.add(Exchange(question: question, answer: reader.arrivedText)) }
        do {
            try await reader.read(answer)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            pointing?.stop()
            stop(because: error, voice: voice)
        }
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

    private func cancel() {
        answering?.cancel()
        answering = nil
        hearing?.cancel()
        hearing = nil
        picture?.cancel()
        picture = nil
        speaking?.stop()
        speaking = nil
        pointing?.stop()
        pointing = nil
        board.stop()
        cursorStage.hide()
    }
}
