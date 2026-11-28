import AppKit
import OSLog

final class Turn {
    private let audioSource: any AudioSource
    private let speech: SpeechToText
    private let speaker: Speaker
    private let screen: ScreenCapture
    private let brain: BrainWithJobs
    private let conversation: Conversation
    private let cursorStage: CursorStage
    private let pointer: Pointer
    private let board: Board
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private let parts: TurnParts
    private lazy var follower = VoiceFollower(board: board) { [cursorStage] in cursorStage.hide() }
    private let failureLines: FailureLines
    private lazy var reading = BrainReading(
        brain: brain,
        conversation: conversation,
        board: board,
        follower: follower
    ) { [weak self] error, voice, question in
        self?.stop(because: error, voice: voice, showingUnder: question.failureShownUnder)
    }

    init(
        audioSource: any AudioSource,
        speech: SpeechToText,
        speaker: Speaker,
        screen: ScreenCapture,
        brain: BrainWithJobs,
        conversation: Conversation,
        cursor: UmiCursor,
        cursorPanel: CursorPanel,
        pointer: Pointer,
        board: Board,
        parts: TurnParts
    ) {
        self.audioSource = MeteredAudioSource(source: audioSource, cursor: cursor)
        self.speech = speech
        self.speaker = speaker
        self.screen = screen
        self.brain = brain
        self.conversation = conversation
        failureLines = FailureLines(conversation: conversation)
        cursorStage = CursorStage(cursor: cursor, panel: cursorPanel)
        self.pointer = pointer
        self.board = board
        self.parts = parts
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

    var isAnswering: Bool {
        parts.speaking != nil || board.isDrawing
    }

    func escape() {
        guard isAnswering || parts.pointing?.isShowing == true || cursorStage.isFailed else { return }
        cancel()
        logger.notice("Esc: the question stopped")
    }

    func ask(typed text: String, readsAloud: Bool) {
        cancel()
        guard let underPointer = PointerScreen.current() else {
            logger.error("No screen is under the pointer")
            return
        }
        let question = AskedQuestion(id: conversation.addQuestion(text, way: .typed), way: .typed)
        logger.notice("A typed question came: \(text.count, privacy: .public) characters")
        let speaking = speaker.typedAnswer(readsAloud: readsAloud)
        parts.speaking = speaking
        start(speaking, for: question.way)
        guard screen.isAllowed else {
            stopWithoutScreen(voice: speaking, showingUnder: question.id)
            return
        }
        let (pointing, picture) = startLooking(at: underPointer)
        cursorStage.think()
        parts.answering = Task { [weak self] in
            await self?.answer(typed: text, question: question, picture: picture, voice: speaking, pointing: pointing)
        }
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
        parts.speaking = speaking
        guard screen.isAllowed else {
            start(speaking, for: .spoken)
            stopWithoutScreen(voice: speaking, showingUnder: nil)
            return
        }
        startLooking(at: underPointer)
        parts.trail = pointer.trail(on: underPointer.screen.frame, from: underPointer.pointer)
        cursorStage.listen()
        hearing.start()
        start(speaking, for: .spoken)
        parts.hearing = hearing
        logger.notice("Hold began")
    }

    private func end() {
        guard parts.answering == nil, let hearing = parts.hearing, let picture = parts.picture,
              let speaking = parts.speaking else { return }
        cursorStage.think()
        logger.notice("Hold ended")
        let hasMark = parts.trail?.end() ?? false
        logger.notice("The hold had a mark: \(hasMark, privacy: .public)")
        let pointing = parts.pointing
        parts.answering = Task { [weak self] in
            await self?.answer(heardBy: hearing, picture: picture, voice: speaking, pointing: pointing)
        }
    }

    private func answer(
        heardBy hearing: HoldHearing,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer,
        pointing: Pointing?
    ) async {
        defer {
            parts.release(voice)
            parts.release(picture)
            parts.release(hearing)
        }
        do {
            let heard = try await hearing.finish()
            guard !Task.isCancelled else { return }
            switch heard {
            case .words(let text):
                logger.notice("Heard \(text.count, privacy: .public) characters")
                let question = AskedQuestion(id: conversation.addQuestion(text, way: .spoken), way: .spoken)
                defer { conversation.endAnswer(to: question.id) }
                await reading.answer(text, to: question, picture: picture, voice: voice, pointing: pointing)
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
            stop(because: error, voice: voice, showingUnder: nil)
            await follower.follow(voice, pointing: pointing)
        }
    }

    private func answer(
        typed text: String,
        question: AskedQuestion,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer,
        pointing: Pointing?
    ) async {
        defer {
            parts.release(voice)
            parts.release(picture)
            conversation.endAnswer(to: question.id)
        }
        await reading.answer(text, to: question, picture: picture, voice: voice, pointing: pointing)
    }

    private func stopWithoutScreen(voice: SpokenAnswer, showingUnder typedQuestion: ChatMessage.ID?) {
        parts.answering = Task { [weak self, screen] in
            let refusal = await screen.refusal()
            guard let self else { return }
            defer {
                parts.release(voice)
                if let typedQuestion {
                    conversation.endAnswer(to: typedQuestion)
                }
            }
            guard !Task.isCancelled else { return }
            stop(because: refusal, voice: voice, showingUnder: typedQuestion)
            await follower.followToEnd(voice, pointing: nil)
        }
    }

    private func start(_ voice: SpokenAnswer, for way: ChatMessage.Way) {
        voice.start { [weak self] voice in
            self?.voiceFailed(voice, for: way)
        }
    }

    private func voiceFailed(_ voice: SpokenAnswer, for way: ChatMessage.Way) {
        guard parts.speaking === voice else { return }
        switch way {
        case .spoken:
            logger.error("The question failed: the voice could not speak")
            failAnswer()
        case .typed:
            logger.error("The voice could not speak: the typed answer goes on in the chat")
            cursorStage.hide()
        }
    }

    private func stop(because error: any Error, voice: SpokenAnswer, showingUnder typedQuestion: ChatMessage.ID?) {
        guard !failureLines.speak(for: error, by: voice, under: typedQuestion) else { return }
        fail(because: error)
    }

    @discardableResult
    private func startLooking(at underPointer: PointerScreen) -> (Pointing, Task<ScreenPicture, any Error>) {
        let pointing = pointer.pointing(
            on: underPointer.screen.frame,
            cursorRest: { [cursorStage] in cursorStage.restBesidePointer },
            onDepart: { [cursorStage] in cursorStage.hide() }
        )
        let picture = Task { [screen] in
            try await screen.picture(ofDisplay: underPointer.displayID)
        }
        parts.pointing = pointing
        parts.picture = picture
        return (pointing, picture)
    }

    private func fail(because error: any Error) {
        logger.error("The question failed with no line to speak: \(StopReason.text(for: error), privacy: .public)")
        failAnswer()
    }

    private func failAnswer() {
        cancel()
        cursorStage.fail()
    }

    private func cancel() {
        parts.stop()
        board.stop()
        cursorStage.hide()
    }
}
