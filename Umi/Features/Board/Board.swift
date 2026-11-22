import OSLog

final class Board {
    static let untitled = "Umi Board"

    private let content: BoardContent
    private let window: BoardWindow
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Board")
    private var lastComplete: Drawing?
    private var draft: DrawingDraft?

    init(content: BoardContent, window: BoardWindow) {
        self.content = content
        self.window = window
    }

    var isDrawing: Bool {
        draft != nil
    }

    func open() {
        draft = DrawingDraft()
        content.startDrawing()
        window.setTitle(Self.untitled)
        window.show()
        logger.notice("Board opened, Drawing… shows")
    }

    func name(_ title: String) {
        guard draft != nil else { return }
        draft?.title = title
        window.setTitle(title)
    }

    func add(_ marks: [BoardMark]) throws {
        guard draft != nil else { return }
        try draft?.add(marks)
        let row = draft?.rows.count ?? 0
        logger.notice("Board placed row \(row, privacy: .public) with \(marks.count, privacy: .public) marks")
    }

    func endReading() {
        draft?.endReading()
    }

    func reveal(sentences count: Int) {
        guard var draft else { return }
        let marks = draft.reveal(sentences: count)
        self.draft = draft
        if !marks.isEmpty {
            content.reveal(marks)
            let row = draft.revealedRows
            logger.notice("Board drew up to row \(row, privacy: .public): \(marks.count, privacy: .public) marks")
        }
        if let failsAt = draft.failsAtSentence, count > failsAt {
            abandon(because: "its failure line showed")
        }
    }

    func fail() {
        guard draft != nil else { return }
        draft?.fail()
        logger.notice("Board drawing failed; it goes when the failure line shows")
    }

    func answerEnded() {
        end(because: "the answer ended before it was complete")
    }

    func stop() {
        end(because: "it was stopped")
    }

    private func end(because reason: String) {
        guard let draft else { return }
        guard draft.isComplete else {
            abandon(because: reason)
            return
        }
        lastComplete = draft.drawing
        self.draft = nil
        logger.notice("Board drawing complete with \(draft.drawing.marks.count, privacy: .public) marks")
    }

    private func abandon(because reason: String) {
        draft = nil
        if let lastComplete {
            content.show(lastComplete)
            window.setTitle(lastComplete.title)
            logger.notice("Board drawing dropped (\(reason, privacy: .public)); the last complete drawing is back")
        } else {
            content.clear()
            window.hide()
            logger.notice("Board drawing dropped (\(reason, privacy: .public)); the board closed")
        }
    }
}
