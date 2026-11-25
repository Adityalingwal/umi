nonisolated struct PointTagParser {
    enum Part: Equatable {
        case text(String)
        case nameStart(PointLocation, PointLabel?)
        case dropped(Problem)
    }

    enum Problem: Equatable {
        case malformedTag
        case unfinishedTag
        case emptyName
    }

    private static let longestTag = 200
    private static let openTag = "<point"
    private static let closeTag = "</point"

    private var buffer = ""
    private var waitingPoint: (location: PointLocation, label: PointLabel?)?
    private var isInsideName = false

    mutating func add(_ piece: String) -> [Part] {
        buffer += piece
        return drain(isFinal: false)
    }

    mutating func finish() -> [Part] {
        var parts = drain(isFinal: true)
        if waitingPoint != nil {
            waitingPoint = nil
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
            let end = brackets.first { !Self.endsInsideLabel(text[..<$0]) || Self.opensPoint(text[$0...]) }
                ?? (mustDecide ? brackets.first : nil)
            guard let end, buffer[end] == ">" else {
                if !Self.mayBecomeTag(buffer) {
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
        !attributes.lowercased().hasPrefix(openTag) || point(in: attributes) != nil
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
        if tag.lowercased().hasPrefix(Self.closeTag) {
            readClose(tag, into: &parts)
            return
        }
        guard !tag.hasSuffix("/>") else {
            parts.append(.dropped(.emptyName))
            return
        }
        guard let point = Self.point(in: tag) else {
            parts.append(.dropped(.malformedTag))
            return
        }
        if waitingPoint != nil {
            parts.append(.dropped(.emptyName))
        }
        waitingPoint = point
    }

    private mutating func readClose(_ tag: String, into parts: inout [Part]) {
        if isInsideName, tag.lowercased().wholeMatch(of: /<\/point\s*>/) != nil {
            isInsideName = false
        } else if waitingPoint != nil {
            waitingPoint = nil
            parts.append(.dropped(.emptyName))
        } else {
            parts.append(.dropped(.malformedTag))
        }
    }

    private mutating func emit(_ text: String, into parts: inout [Part]) {
        guard !text.isEmpty else { return }
        guard let point = waitingPoint, let nameStart = text.firstIndex(where: { !$0.isWhitespace }) else {
            parts.append(.text(text))
            return
        }
        if nameStart > text.startIndex {
            parts.append(.text(String(text[..<nameStart])))
        }
        parts.append(.nameStart(point.location, point.label))
        parts.append(.text(String(text[nameStart...])))
        waitingPoint = nil
        isInsideName = true
    }

    private static func mayBecomeTag(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return openTag.hasPrefix(lowered) || closeTag.hasPrefix(lowered) || isPointTag(lowered)
    }

    private static func opensPoint(_ text: Substring) -> Bool {
        text.lowercased().prefixMatch(of: /<point(\s|\/|>)/) != nil
    }

    private static func isPointTag(_ text: String) -> Bool {
        text.lowercased().prefixMatch(of: /<\/?point(\s|\/|>)/) != nil
    }

    private static func point(in tag: String) -> (location: PointLocation, label: PointLabel?)? {
        let label = tag.firstMatch(of: /\blabel\s*=\s*(?:"([^"]*)"|'([^']*)'|["'].*|([^\s"'<>\/]*))/.ignoresCase())
        var place = tag
        if let label {
            place.removeSubrange(label.range)
        }
        guard let location = location(in: place) else { return nil }
        let written = label.flatMap { $0.output.1 ?? $0.output.2 ?? $0.output.3 }
        return (location, written.flatMap { PointLabel(String($0)) })
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
