import OSLog

struct VoiceFollower {
    private let board: Board
    private let hideCursor: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")

    init(board: Board, hideCursor: @escaping () -> Void) {
        self.board = board
        self.hideCursor = hideCursor
    }

    func follow(_ voice: SpokenAnswer, pointing: Pointing?) async {
        for await event in voice.events {
            guard !Task.isCancelled else { return }
            switch event {
            case .firstSound:
                hideCursor()
            case .piecesStarted(let count):
                board.reveal(sentences: count)
            case .finished:
                hideCursor()
                board.answerEnded()
                pointing?.answerEnded()
                logger.notice("Answer finished")
            }
        }
    }
}
