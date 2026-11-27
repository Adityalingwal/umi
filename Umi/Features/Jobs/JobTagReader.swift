import Foundation

// Takes the job tag out of an answer's text as it streams, so it is never spoken or shown.
nonisolated struct JobTagReader {
    enum Problem: Equatable {
        case unfinishedTag
        case missingNameOrTask
        case secondTag
    }

    private static let opening = "<job"
    private static let closing = "</job>"

    private(set) var request: JobRequest?
    private(set) var problems: [Problem] = []
    private var buffer = ""
    private var isInsideTag = false

    mutating func add(_ piece: String) -> String {
        buffer += piece
        var passed = ""
        while true {
            if isInsideTag {
                guard let end = buffer.range(of: Self.closing, options: .caseInsensitive) else { return passed }
                read(String(buffer[..<end.upperBound]))
                buffer = String(buffer[end.upperBound...])
                isInsideTag = false
            } else if let start = Self.tagStart(in: buffer) {
                passed += buffer[..<start]
                buffer = String(buffer[start...])
                isInsideTag = true
            } else {
                let kept = Self.possibleTagStart(atEndOf: buffer)
                passed += buffer[..<kept]
                buffer = String(buffer[kept...])
                return passed
            }
        }
    }

    // A tag the answer never closed starts nothing.
    mutating func finish() -> String {
        defer {
            buffer = ""
            isInsideTag = false
        }
        guard !isInsideTag else {
            problems.append(.unfinishedTag)
            return ""
        }
        return buffer
    }

    private mutating func read(_ tag: String) {
        guard request == nil else {
            problems.append(.secondTag)
            return
        }
        guard let match = tag.wholeMatch(of: /<job\b([^>]*)>([\s\S]*)<\/job>/.ignoresCase()) else {
            problems.append(.missingNameOrTask)
            return
        }
        let attributes = String(match.output.1)
        let task = String(match.output.2).trimmingCharacters(in: .whitespacesAndNewlines)
        let name = Self.value(of: attributes.firstMatch(of: /\bname\s*=\s*"([^"]*)"/.ignoresCase())?.output.1)
        guard let name, !task.isEmpty else {
            problems.append(.missingNameOrTask)
            return
        }
        let startLine = Self.value(of: attributes.firstMatch(of: /\bsay\s*=\s*"([^"]*)"/.ignoresCase())?.output.1)
        request = JobRequest(name: name, task: task, startLine: startLine)
    }

    private static func value(of attribute: Substring?) -> String? {
        let value = attribute?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func tagStart(in text: String) -> String.Index? {
        var searched = text.startIndex
        while let found = text.range(of: opening, options: .caseInsensitive, range: searched..<text.endIndex) {
            guard found.upperBound < text.endIndex else { return nil }
            let next = text[found.upperBound]
            if next.isWhitespace || next == ">" {
                return found.lowerBound
            }
            searched = found.upperBound
        }
        return nil
    }

    // The end of the text may be the first letters of a tag still arriving.
    private static func possibleTagStart(atEndOf text: String) -> String.Index {
        guard let last = text.lastIndex(of: "<") else { return text.endIndex }
        let rest = text[last...].lowercased()
        return opening.hasPrefix(rest) ? last : text.endIndex
    }
}
