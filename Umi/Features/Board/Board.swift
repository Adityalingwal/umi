import OSLog

final class Board {
    private let content: BoardContent
    private let window: BoardWindow
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Board")
    private var lastComplete: Drawing?
    private var unfinished: Drawing?
    private var draft: DrawingDraft?

    init(content: BoardContent, window: BoardWindow) {
        self.content = content
        self.window = window
    }

    var isDrawing: Bool {
        draft != nil
    }

    var brief: String? {
        BoardBrief.text(unfinished: unfinished, lastComplete: lastComplete, isShown: window.isShown)
    }

    func expectDrawing() {
        guard draft == nil, lastComplete == nil, unfinished == nil else { return }
        open(nil)
    }

    func open(_ title: String?) {
        if var draft, let title, !draft.isEdit, draft.rows.isEmpty {
            draft.title = title
            self.draft = draft
            window.setTitle(title)
            return
        }
        unfinished = nil
        let draft = DrawingDraft(title: title)
        self.draft = draft
        content.startDrawing()
        window.setTitle(draft.title)
        window.show()
        logger.notice("Board opened for a new drawing, Drawing… shows")
    }

    func edit(_ title: String) throws {
        guard let base = unfinished ?? lastComplete else { throw DrawingError.noDiagram }
        let source = unfinished == nil ? "the last complete drawing" : "the drawing that was stopped"
        draft = DrawingDraft(title: title, base: base)
        content.startEditing(base)
        window.setTitle(title)
        window.show()
        logger.notice("Board edits \(source, privacy: .public): \(base.marks.count, privacy: .public) marks stay")
    }

    func reopen() throws {
        guard let lastComplete else { throw DrawingError.noDiagram }
        content.show(lastComplete)
        window.setTitle(lastComplete.title)
        window.show()
        let count = lastComplete.marks.count
        logger.notice("Board shows the last complete drawing again: \(count, privacy: .public) marks")
    }

    func add(_ marks: [BoardMark], removing removedIDs: [String]) throws {
        guard draft != nil else { return }
        guard let row = try draft?.add(marks, removing: removedIDs) else { return }
        let number = draft?.rows.count ?? 0
        let total = draft?.markCount ?? 0
        logger.notice(
            """
            Board placed row \(number, privacy: .public): \(row.added.count, privacy: .public) added, \
            \(row.removedIDs.count, privacy: .public) removed, \(total, privacy: .public) on the board
            """
        )
    }

    func endReading() {
        draft?.endReading()
    }

    func reveal(sentences count: Int) {
        guard var draft else { return }
        let rows = draft.reveal(sentences: count)
        self.draft = draft
        if !rows.isEmpty {
            content.reveal(rows)
            let added = rows.reduce(0) { $0 + $1.added.count }
            let removed = rows.reduce(0) { $0 + $1.removedIDs.count }
            let row = draft.revealedRows
            logger.notice(
                """
                Board drew up to row \(row, privacy: .public): \(added, privacy: .public) added, \
                \(removed, privacy: .public) removed
                """
            )
        }
        if let failsAt = draft.failsAtSentence, count > failsAt {
            abandon(because: "its failure line started playing")
        }
    }

    func fail() {
        guard draft != nil else { return }
        draft?.fail()
        logger.notice("Board drawing failed; it goes when the failure line starts playing")
    }

    func answerEnded() {
        end(because: "the answer ended before it was complete")
    }

    func answerRead() {
        guard draft?.isEdit != true, unfinished != nil else { return }
        unfinished = nil
        logger.notice("Board forgets the stopped drawing: this answer did not edit it")
    }

    // The brain no longer knows the chat, so a drawing on screen goes too.
    func forget() {
        draft = nil
        unfinished = nil
        lastComplete = nil
        content.clear()
        window.hide()
        logger.notice("Board forgets its drawings: the chat was cleared")
    }

    func stop() {
        guard let draft else { return }
        if !draft.isComplete, draft.revealedRows > 0 || !draft.isEdit && draft.isNamed {
            let stopped = draft.shownDrawing
            unfinished = stopped
            let count = stopped.marks.count
            logger.notice("Board keeps the stopped drawing for a correction: \(count, privacy: .public) marks")
        }
        end(because: "it was stopped")
    }

    private func end(because reason: String) {
        guard let draft else { return }
        guard draft.isComplete else {
            abandon(because: reason)
            return
        }
        lastComplete = draft.drawing
        unfinished = nil
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
