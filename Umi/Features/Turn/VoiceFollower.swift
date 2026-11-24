import OSLog

struct VoiceFollower {
    private let subtitles: Subtitles
    private let board: Board
    private let hideCursor: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")

    init(subtitles: Subtitles, board: Board, hideCursor: @escaping () -> Void) {
        self.subtitles = subtitles
        self.board = board
        self.hideCursor = hideCursor
    }

    func follow(_ voice: SpokenAnswer, pointing: Pointing?) async {
        for await event in voice.events {
            guard !Task.isCancelled else { return }
            switch event {
            case .show(let text):
                hideCursor()
                subtitles.show(text)
            case .sentencesShown(let count):
                board.reveal(sentences: count)
            case .finished:
                hideCursor()
                subtitles.finish()
                board.answerEnded()
                pointing?.answerEnded()
                logger.notice("Answer finished")
            }
        }
    }
}
