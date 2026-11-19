import Foundation

struct SentenceSplitter {
    private static let endMarks: Set<Character> = [".", "!", "?", "।"]

    private var pending = ""

    mutating func add(_ piece: String) -> [String] {
        pending += piece
        var sentences: [String] = []
        while let end = Self.sentenceEnd(in: pending) {
            let sentence = pending[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            pending = String(pending[end...])
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
        }
        return sentences
    }

    mutating func flush() -> String? {
        let rest = pending.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = ""
        return rest.isEmpty ? nil : rest
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
