import Foundation

struct DrawingReader {
    private static let mostParts = 12
    private static let longestLine = 8_000

    private var pending = ""
    private var isEnded = false
    private var hasTitle = false
    private var parts = 0
    private var hasMarks = false

    mutating func add(_ piece: String) {
        pending += piece
    }

    mutating func end() {
        isEnded = true
    }

    mutating func nextLine() throws -> DrawingLine? {
        while let text = try takeText() {
            if let line = try read(text) {
                return line
            }
        }
        if isEnded, !hasMarks {
            throw DrawingError.empty
        }
        return nil
    }

    private mutating func takeText() throws -> String? {
        if let newline = pending.firstIndex(where: \.isNewline) {
            let text = String(pending[..<newline])
            pending = String(pending[pending.index(after: newline)...])
            return text
        }
        guard pending.count <= Self.longestLine else { throw DrawingError.tooLarge }
        guard isEnded, !pending.isEmpty else { return nil }
        defer { pending = "" }
        return pending
    }

    private mutating func read(_ text: String) throws -> DrawingLine? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let line = try DrawingLine.decode(trimmed)
        switch line {
        case .title:
            guard !hasTitle else { throw DrawingError.unreadableLine }
            hasTitle = true
        case .part(_, let marks):
            guard hasTitle else { throw DrawingError.unreadableLine }
            parts += 1
            guard parts <= Self.mostParts else { throw DrawingError.tooLarge }
            hasMarks = hasMarks || !marks.isEmpty
        }
        return line
    }
}
