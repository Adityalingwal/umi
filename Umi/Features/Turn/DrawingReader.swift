import Foundation

struct DrawingReader {
    private static let mostParts = 12
    private static let longestLine = 8_000

    private var pending = ""
    private var isEnded = false
    private var start: Start?
    private var parts = 0
    private var hasMarks = false

    private enum Start {
        case newDrawing
        case edit
        case reopen
    }

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
        if isEnded, isEmpty {
            throw DrawingError.empty
        }
        return nil
    }

    private var isEmpty: Bool {
        switch start {
        case .newDrawing, nil: !hasMarks
        case .edit: parts == 0
        case .reopen: false
        }
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
        case .newDrawing:
            try begin(.newDrawing)
        case .edit:
            try begin(.edit)
        case .reopen:
            try begin(.reopen)
        case .part(_, let marks, let removedIDs):
            guard start != nil else { throw DrawingError.unreadableLine }
            if start == .reopen, !marks.isEmpty || !removedIDs.isEmpty { throw DrawingError.unreadableLine }
            parts += 1
            guard parts <= Self.mostParts else { throw DrawingError.tooLarge }
            hasMarks = hasMarks || !marks.isEmpty
        }
        return line
    }

    private mutating func begin(_ kind: Start) throws {
        guard start == nil else { throw DrawingError.unreadableLine }
        start = kind
    }
}
