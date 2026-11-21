struct DrawingDraft {
    private static let mostMarks = 80

    var title = Board.untitled
    private(set) var rows: [[PlacedMark]] = []
    private(set) var revealedRows = 0
    private(set) var isRead = false
    private(set) var failsAtSentence: Int?
    private var layout = BoardLayout()

    var isComplete: Bool {
        isRead && failsAtSentence == nil && revealedRows == rows.count && !rows.isEmpty
    }

    var drawing: Drawing {
        Drawing(title: title, marks: layout.marks)
    }

    mutating func add(_ marks: [BoardMark]) throws {
        guard layout.marks.count + marks.count <= Self.mostMarks else { throw DrawingError.tooLarge }
        rows.append(try layout.place(marks))
    }

    mutating func reveal(sentences count: Int) -> [PlacedMark] {
        let target = min(count, rows.count)
        guard target > revealedRows else { return [] }
        defer { revealedRows = target }
        return rows[revealedRows..<target].flatMap(\.self)
    }

    mutating func endReading() {
        isRead = true
    }

    mutating func fail() {
        failsAtSentence = failsAtSentence ?? rows.count
    }
}
