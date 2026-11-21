struct DrawingDraft {
    private static let mostMarks = 80

    var title: String
    private(set) var rows: [DrawingRow] = []
    private(set) var revealedRows = 0
    private(set) var isRead = false
    private(set) var failsAtSentence: Int?
    private var shownMarks: [PlacedMark]
    private var layout: BoardLayout

    init(title: String, base: Drawing? = nil) {
        self.title = title
        shownMarks = base?.marks ?? []
        layout = BoardLayout(marks: base?.marks ?? [])
    }

    var isComplete: Bool {
        isRead && failsAtSentence == nil && revealedRows == rows.count && !rows.isEmpty
    }

    var drawing: Drawing {
        Drawing(title: title, marks: layout.marks)
    }

    var shownDrawing: Drawing {
        Drawing(title: title, marks: shownMarks)
    }

    var markCount: Int {
        layout.marks.count
    }

    mutating func add(_ marks: [BoardMark], removing removedIDs: [String]) throws -> DrawingRow {
        let removed = layout.remove(removedIDs + marks.map(\.id))
        guard layout.marks.count + marks.count <= Self.mostMarks else { throw DrawingError.tooLarge }
        let row = DrawingRow(added: try layout.place(marks), removedIDs: removed)
        rows.append(row)
        return row
    }

    mutating func reveal(sentences count: Int) -> [DrawingRow] {
        let target = min(count, rows.count)
        guard target > revealedRows else { return [] }
        let revealed = Array(rows[revealedRows..<target])
        revealedRows = target
        for row in revealed {
            shownMarks.removeAll { row.removedIDs.contains($0.id) }
            shownMarks += row.added
        }
        return revealed
    }

    mutating func endReading() {
        isRead = true
    }

    mutating func fail() {
        failsAtSentence = failsAtSentence ?? rows.count
    }
}
