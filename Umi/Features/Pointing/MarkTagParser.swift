nonisolated struct MarkTagParser {
    enum Part: Equatable {
        case text(String)
        case nameStart(MarkLocation, PointLabel?)
        case dropped(Problem)
    }

    enum Problem: Equatable {
        case malformedTag
        case unfinishedTag
        case emptyName
    }

    private static let longestTag = 200

    private var buffer = ""
    private var waitingMark: MarkTag?
    private var openName: MarkTag.Name?

    mutating func add(_ piece: String) -> [Part] {
        buffer += piece
        return drain(isFinal: false)
    }

    mutating func finish() -> [Part] {
        var parts = drain(isFinal: true)
        if waitingMark != nil {
            waitingMark = nil
            parts.append(.dropped(.emptyName))
        }
        return parts
    }

    private mutating func drain(isFinal: Bool) -> [Part] {
        var parts: [Part] = []
        while let open = buffer.firstIndex(of: "<") {
            emit(String(buffer[..<open]), into: &parts)
            buffer = String(buffer[open...])
            let text = buffer
            let brackets = text.indices.dropFirst().lazy.filter { "<>".contains(text[$0]) }
            let mustDecide = isFinal || text.count > Self.longestTag
            let end = brackets.first { !Self.endsInsideLabel(text[..<$0]) || MarkTag.opens(text[$0...]) }
                ?? (mustDecide ? brackets.first : nil)
            guard let end, buffer[end] == ">" else {
                if !MarkTag.mayBecomeTag(buffer) {
                    emitOpeningBracket(into: &parts)
                } else if let end {
                    dropUnclosedTag(before: end, isCutOff: false, into: &parts)
                } else if isFinal || buffer.count > Self.longestTag {
                    dropUnclosedTag(before: buffer.endIndex, isCutOff: isFinal, into: &parts)
                } else {
                    return parts
                }
                continue
            }
            let tag = String(buffer[...end])
            guard MarkTag.isTag(tag) else {
                emitOpeningBracket(into: &parts)
                continue
            }
            buffer = String(buffer[buffer.index(after: end)...])
            read(tag, into: &parts)
        }
        emit(buffer, into: &parts)
        buffer = ""
        return parts
    }

    private mutating func dropUnclosedTag(before end: String.Index, isCutOff: Bool, into parts: inout [Part]) {
        let tag = buffer[..<end]
        let attributesEnd = tag.lastIndex { "=\"'".contains($0) }.map(tag.index(after:))
            ?? tag.firstIndex(where: \.isWhitespace)
            ?? tag.endIndex
        let rest = tag[attributesEnd...].drop { $0.isWhitespace || $0.isNumber || "+-.,".contains($0) }
        let attributes = tag[..<rest.startIndex]
        let keepsRest = !Self.endsInsideLabel(attributes) && (!isCutOff || Self.hasWholeLocation(String(attributes)))
        buffer = String(buffer[end...])
        parts.append(.dropped(.unfinishedTag))
        if keepsRest {
            emit(String(rest), into: &parts)
        }
    }

    // A tag cut off by the answer's end may stop inside its attributes, and those letters are not a name.
    private static func hasWholeLocation(_ attributes: String) -> Bool {
        !MarkTag.startsOpening(attributes) || MarkTag(attributes) != nil
    }

    // Words after an unclosed label quote belong to the label, which is never spoken.
    private static func endsInsideLabel(_ attributes: Substring) -> Bool {
        guard let opening = attributes.matches(of: /\blabel\s*=\s*(["'])/.ignoresCase()).last else { return false }
        return !attributes[opening.range.upperBound...].contains(opening.output.1)
    }

    private mutating func emitOpeningBracket(into parts: inout [Part]) {
        buffer.removeFirst()
        emit("<", into: &parts)
    }

    private mutating func read(_ tag: String, into parts: inout [Part]) {
        if MarkTag.isClosing(tag) {
            readClose(tag, into: &parts)
            return
        }
        guard !tag.hasSuffix("/>") else {
            parts.append(.dropped(.emptyName))
            return
        }
        guard let mark = MarkTag(tag) else {
            parts.append(.dropped(.malformedTag))
            return
        }
        if waitingMark != nil {
            parts.append(.dropped(.emptyName))
        }
        waitingMark = mark
    }

    private mutating func readClose(_ tag: String, into parts: inout [Part]) {
        if let openName, MarkTag.closes(tag, named: openName) {
            self.openName = nil
        } else if waitingMark != nil {
            waitingMark = nil
            parts.append(.dropped(.emptyName))
        } else {
            parts.append(.dropped(.malformedTag))
        }
    }

    private mutating func emit(_ text: String, into parts: inout [Part]) {
        guard !text.isEmpty else { return }
        guard let mark = waitingMark, let nameStart = text.firstIndex(where: { !$0.isWhitespace }) else {
            parts.append(.text(text))
            return
        }
        if nameStart > text.startIndex {
            parts.append(.text(String(text[..<nameStart])))
        }
        parts.append(.nameStart(mark.location, mark.label))
        parts.append(.text(String(text[nameStart...])))
        waitingMark = nil
        openName = mark.name
    }
}
