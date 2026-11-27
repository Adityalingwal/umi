import Foundation

// Takes the job tag out of an answer's text as it streams, so it is never spoken or shown.
nonisolated struct JobTagReader {
    enum Problem: Equatable {
        case unfinishedTag
        case missingNameOrTask
        case missingMessage
        case secondTag
        case notStandingAlone
    }

    private enum Kind: String, CaseIterable {
        case start = "job"
        case stop = "job-stop"
        case message = "job-message"

        var opening: String { "<" + rawValue }
        var closing: String { "</" + rawValue + ">" }
    }

    private(set) var ask: JobAsk?
    private(set) var problems: [Problem] = []
    private var buffer = ""
    private var openKind: Kind?
    private var hasTextBesideTag = false

    mutating func add(_ piece: String) -> String {
        buffer += piece
        var passed = ""
        while true {
            if let kind = openKind {
                guard let end = Self.tagEnd(of: kind, in: buffer) else { return passed }
                read(String(buffer[..<end]), as: kind)
                buffer = String(buffer[end...])
                openKind = nil
            } else if let (start, kind) = Self.tagStart(in: buffer) {
                note(buffer[..<start])
                passed += buffer[..<start]
                buffer = String(buffer[start...])
                openKind = kind
            } else {
                let kept = Self.possibleTagStart(atEndOf: buffer)
                note(buffer[..<kept])
                passed += buffer[..<kept]
                buffer = String(buffer[kept...])
                return passed
            }
        }
    }

    // A tag the answer never closed does nothing, and nor does one inside other words, such as a quote of one.
    mutating func finish() -> String {
        let wasInsideTag = openKind != nil
        defer {
            buffer = ""
            openKind = nil
        }
        if wasInsideTag {
            problems.append(.unfinishedTag)
        } else {
            note(buffer[...])
        }
        if ask != nil, hasTextBesideTag {
            ask = nil
            problems.append(.notStandingAlone)
        }
        return wasInsideTag ? "" : buffer
    }

    private mutating func note(_ text: Substring) {
        if text.contains(where: { !$0.isWhitespace }) {
            hasTextBesideTag = true
        }
    }

    private mutating func read(_ tag: String, as kind: Kind) {
        guard ask == nil else {
            problems.append(.secondTag)
            return
        }
        let attributes = Self.attributes(of: tag)
        let say = Self.value(of: attributes.firstMatch(of: /\bsay\s*=\s*"([^"]*)"/.ignoresCase())?.output.1)
        let content = Self.content(of: tag, kind: kind)
        switch kind {
        case .start:
            let name = Self.value(of: attributes.firstMatch(of: /\bname\s*=\s*"([^"]*)"/.ignoresCase())?.output.1)
            guard let name, !content.isEmpty else {
                problems.append(.missingNameOrTask)
                return
            }
            ask = .start(JobRequest(name: name, task: content, startLine: say))
        case .stop:
            ask = .stop(say: say)
        case .message:
            guard !content.isEmpty else {
                problems.append(.missingMessage)
                return
            }
            ask = .message(content, say: say)
        }
    }

    private static func attributes(of tag: String) -> Substring {
        guard let end = tag.firstIndex(of: ">") else { return "" }
        return tag[tag.startIndex..<end]
    }

    private static func content(of tag: String, kind: Kind) -> String {
        guard let open = tag.firstIndex(of: ">"),
              let close = tag.range(of: kind.closing, options: [.caseInsensitive, .backwards]),
              open < close.lowerBound else { return "" }
        return tag[tag.index(after: open)..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func value(of attribute: Substring?) -> String? {
        let value = attribute?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    // An opening that ends in "/>" is the whole tag; otherwise the tag runs to its closing.
    private static func tagEnd(of kind: Kind, in text: String) -> String.Index? {
        guard let openEnd = text.firstIndex(of: ">") else { return nil }
        if openEnd > text.startIndex, text[text.index(before: openEnd)] == "/" {
            return text.index(after: openEnd)
        }
        return text.range(of: kind.closing, options: .caseInsensitive, range: openEnd..<text.endIndex)?.upperBound
    }

    // "<job" begins all three openings, so the letters after it decide which one it is.
    private static func tagStart(in text: String) -> (String.Index, Kind)? {
        var searched = text.startIndex
        let opening = Kind.start.opening
        while let found = text.range(of: opening, options: .caseInsensitive, range: searched..<text.endIndex) {
            let rest = text[found.upperBound...].lowercased()
            let kind = Kind.allCases.first { kind in
                let suffix = kind.rawValue.dropFirst(Kind.start.rawValue.count)
                guard rest.hasPrefix(suffix), let next = rest.dropFirst(suffix.count).first else { return false }
                return next.isWhitespace || next == ">" || next == "/"
            }
            if let kind {
                return (found.lowerBound, kind)
            }
            searched = found.upperBound
        }
        return nil
    }

    // The end of the text may be the first letters of a tag still arriving.
    private static func possibleTagStart(atEndOf text: String) -> String.Index {
        guard let last = text.lastIndex(of: "<") else { return text.endIndex }
        let rest = text[last...].lowercased()
        return Kind.allCases.contains { $0.opening.hasPrefix(rest) } ? last : text.endIndex
    }
}
