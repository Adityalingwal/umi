import Foundation

struct DrawingReader {
    private static let mostParts = 12
    private static let longestLine = 8_000

    private(set) var spokenText = ""
    private var pending = ""
    private var hasTitle = false
    private var parts = 0
    private var hasMarks = false

    mutating func add(_ piece: String) throws -> [DrawingLine] {
        pending += piece
        var lines: [DrawingLine] = []
        while let newline = pending.firstIndex(where: \.isNewline) {
            let text = String(pending[..<newline])
            pending = String(pending[pending.index(after: newline)...])
            if let line = try read(text) {
                lines.append(line)
            }
        }
        guard pending.count <= Self.longestLine else { throw DrawingError.tooLarge }
        return lines
    }

    mutating func finish() throws -> [DrawingLine] {
        let text = pending
        pending = ""
        let lines = try read(text).map { [$0] } ?? []
        guard hasMarks else { throw DrawingError.empty }
        return lines
    }

    private mutating func read(_ text: String) throws -> DrawingLine? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let line = try DrawingLine.decode(trimmed)
        switch line {
        case .title:
            guard !hasTitle else { throw DrawingError.unreadableLine }
            hasTitle = true
        case let .part(say, marks):
            guard hasTitle else { throw DrawingError.unreadableLine }
            parts += 1
            guard parts <= Self.mostParts else { throw DrawingError.tooLarge }
            hasMarks = hasMarks || !marks.isEmpty
            spokenText += spokenText.isEmpty ? say : " " + say
        }
        return line
    }
}
