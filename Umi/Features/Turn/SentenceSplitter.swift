import Foundation

struct SentenceSplitter {
    struct Sentence {
        let text: String
        let nameStart: String.Index?
    }

    private static let endMarks: Set<Character> = [".", "!", "?", "।"]

    private var pending = ""
    private var nameMark: Int?
    private var hasSentence = false

    var isAtStart: Bool {
        !hasSentence && pending.allSatisfy(\.isWhitespace)
    }

    mutating func markName() {
        nameMark = pending.unicodeScalars.count
    }

    mutating func add(_ piece: String) -> [Sentence] {
        pending += piece
        var sentences: [Sentence] = []
        while let end = Self.sentenceEnd(in: pending) {
            let sentence = take(pending[..<end])
            pending = String(pending[end...])
            if let sentence {
                sentences.append(sentence)
            }
        }
        return sentences
    }

    mutating func flush() -> Sentence? {
        let sentence = take(pending[...])
        pending = ""
        return sentence
    }

    private mutating func take(_ raw: Substring) -> Sentence? {
        let length = raw.unicodeScalars.count
        let mark = nameMark.flatMap { $0 < length ? $0 : nil }
        nameMark = nameMark.map { $0 - length }.flatMap { $0 >= 0 ? $0 : nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        hasSentence = true
        let leading = raw.unicodeScalars.prefix { CharacterSet.whitespacesAndNewlines.contains($0) }.count
        let nameStart = mark.map { mark in
            let offset = min(max(0, mark - leading), text.unicodeScalars.count)
            return text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: offset)
        }
        return Sentence(text: text, nameStart: nameStart)
    }

    private static func sentenceEnd(in text: String) -> String.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if text[index].isNewline {
                return next
            }
            if endMarks.contains(text[index]), next < text.endIndex, text[next].isWhitespace,
               !isListNumber(endingAt: index, in: text) {
                return next
            }
            index = next
        }
        return nil
    }

    private static func isListNumber(endingAt mark: String.Index, in text: String) -> Bool {
        let word = text[..<mark].reversed().prefix { !$0.isWhitespace }
        return !word.isEmpty && word.allSatisfy(\.isNumber)
    }
}
