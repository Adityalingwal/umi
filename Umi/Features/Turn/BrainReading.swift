struct BrainReading {
    private let brain: any Brain
    private let conversation: Conversation
    private let board: Board
    private let follower: VoiceFollower
    private let stopped: (any Error, SpokenAnswer, AskedQuestion) -> Void

    init(
        brain: any Brain,
        conversation: Conversation,
        board: Board,
        follower: VoiceFollower,
        stopped: @escaping (any Error, SpokenAnswer, AskedQuestion) -> Void
    ) {
        self.brain = brain
        self.conversation = conversation
        self.board = board
        self.follower = follower
        self.stopped = stopped
    }

    func answer(
        _ text: String,
        to question: AskedQuestion,
        picture: Task<ScreenPicture, any Error>,
        voice: SpokenAnswer,
        pointing: Pointing?
    ) async {
        let screen: ScreenPicture
        do {
            screen = try await picture.value
            try Task.checkCancellation()
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            pointing?.stop()
            stopped(error, voice, question)
            await follower.followToEnd(voice, pointing: nil)
            return
        }
        let brainQuestion = BrainQuestion(
            text: text,
            screenJPEG: screen.jpegData,
            screenWidth: screen.width,
            screenHeight: screen.height,
            earlierExchanges: conversation.exchanges,
            boardBrief: board.brief
        )
        let answer = brain.answer(brainQuestion)
        await withDiscardingTaskGroup { group in
            group.addTask { await send(answer, for: question, to: voice, pointing: pointing, on: screen) }
            group.addTask { await follower.follow(voice, pointing: pointing) }
        }
        guard voice.isSilent, !Task.isCancelled else { return }
        follower.endWithoutVoice(pointing: pointing)
    }

    private func send(
        _ answer: AsyncThrowingStream<String, any Error>,
        for question: AskedQuestion,
        to voice: SpokenAnswer,
        pointing: Pointing?,
        on picture: ScreenPicture
    ) async {
        let conversation = conversation
        var reader = AnswerReader(voice: voice, pointing: pointing, picture: picture, board: board) { text in
            conversation.writeAnswer(text, to: question.id)
        }
        defer { conversation.writeAnswer(reader.arrivedText, to: question.id) }
        do {
            try await reader.read(answer)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            pointing?.stop()
            stopped(error, voice, question)
        }
    }
}
