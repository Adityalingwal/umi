nonisolated struct PointTagParser {
    enum Part: Equatable {
        case text(String)
        case nameStart(PointLocation)
        case dropped(Problem)
    }

    enum Problem: Equatable {
        case malformedTag
        case unfinishedTag
        case emptyName
        case secondPoint
    }

    private static let longestTag = 64
    private static let openTag = "<point"
    private static let closeTag = "</point"

    private var buffer = ""
    private var waitingLocation: PointLocation?
    private var isInsideName = false
    private var hasPointed = false

    mutating func add(_ piece: String) -> [Part] {
        buffer += piece
        return drain(isFinal: false)
    }

    mutating func finish() -> [Part] {
        var parts = drain(isFinal: true)
        if waitingLocation != nil {
            waitingLocation = nil
            parts.append(.dropped(.emptyName))
        }
        return parts
    }

    private mutating func drain(isFinal: Bool) -> [Part] {
        var parts: [Part] = []
        while let open = buffer.firstIndex(of: "<") {
            emit(String(buffer[..<open]), into: &parts)
            buffer = String(buffer[open...])
            let end = buffer.dropFirst().firstIndex { $0 == "<" || $0 == ">" }
            guard let end, buffer[end] == ">" else {
                if !Self.mayBecomeTag(buffer) {
                    emitOpeningBracket(into: &parts)
                } else if let end {
                    dropUnclosedTag(before: end, into: &parts)
                } else if isFinal || buffer.count > Self.longestTag {
                    dropUnclosedTag(before: buffer.endIndex, into: &parts)
                } else {
                    return parts
                }
                continue
            }
            let tag = String(buffer[...end])
            guard Self.isPointTag(tag) else {
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

    private mutating func dropUnclosedTag(before end: String.Index, into parts: inout [Part]) {
        let tag = buffer[..<end]
        let head = /<\/?point(?:[\s,]*[a-z_\-]+\s*=\s*(?:"[^"<>]*"|'[^'<>]*'|["']?[^\s"'<>,]*))*[\s,]*/
            .ignoresCase()
        let attributesEnd = tag.prefixMatch(of: head)?.range.upperBound
            ?? tag.firstIndex(where: \.isWhitespace)
            ?? tag.endIndex
        let rest = String(tag[attributesEnd...].drop(while: \.isWhitespace))
        buffer = String(buffer[end...])
        parts.append(.dropped(.unfinishedTag))
        emit(rest, into: &parts)
    }

    private mutating func emitOpeningBracket(into parts: inout [Part]) {
        buffer.removeFirst()
        emit("<", into: &parts)
    }

    private mutating func read(_ tag: String, into parts: inout [Part]) {
        if tag.lowercased().hasPrefix(Self.closeTag) {
            readClose(tag, into: &parts)
            return
        }
        guard !tag.hasSuffix("/>") else {
            parts.append(.dropped(.emptyName))
            return
        }
        guard let location = Self.location(in: tag) else {
            parts.append(.dropped(.malformedTag))
            return
        }
        guard !hasPointed else {
            parts.append(.dropped(.secondPoint))
            return
        }
        hasPointed = true
        waitingLocation = location
    }

    private mutating func readClose(_ tag: String, into parts: inout [Part]) {
        if isInsideName, tag.lowercased().wholeMatch(of: /<\/point\s*>/) != nil {
            isInsideName = false
        } else if waitingLocation != nil {
            waitingLocation = nil
            parts.append(.dropped(.emptyName))
        } else {
            parts.append(.dropped(.malformedTag))
        }
    }

    private mutating func emit(_ text: String, into parts: inout [Part]) {
        guard !text.isEmpty else { return }
        guard let location = waitingLocation, let nameStart = text.firstIndex(where: { !$0.isWhitespace }) else {
            parts.append(.text(text))
            return
        }
        if nameStart > text.startIndex {
            parts.append(.text(String(text[..<nameStart])))
        }
        parts.append(.nameStart(location))
        parts.append(.text(String(text[nameStart...])))
        waitingLocation = nil
        isInsideName = true
    }

    private static func mayBecomeTag(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return openTag.hasPrefix(lowered) || closeTag.hasPrefix(lowered) || isPointTag(lowered)
    }

    private static func isPointTag(_ text: String) -> Bool {
        text.lowercased().prefixMatch(of: /<\/?point(\s|\/|>)/) != nil
    }

    private static func location(in tag: String) -> PointLocation? {
        guard tag.lowercased().hasPrefix(openTag) else { return nil }
        var pixelX: Double?
        var pixelY: Double?
        for match in tag.lowercased().matches(of: /\b([xy])\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>\/]*))/) {
            let text = match.output.2 ?? match.output.3 ?? match.output.4 ?? ""
            guard let value = coordinate(in: text) else { return nil }
            if match.output.1 == "x" {
                guard pixelX == nil else { return nil }
                pixelX = value
            } else {
                guard pixelY == nil else { return nil }
                pixelY = value
            }
        }
        guard let pixelX, let pixelY else { return nil }
        return PointLocation(pixelX: pixelX, pixelY: pixelY)
    }

    private static func coordinate(in text: Substring) -> Double? {
        guard let match = text.wholeMatch(of: /\s*(-?[0-9]+(?:\.[0-9]+)?)\s*/) else { return nil }
        return Double(match.output.1)
    }
}
