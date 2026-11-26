import Foundation
import Observation
import OSLog

@Observable
final class Conversation {
    private static let exchangesForBrain = 20

    private(set) var messages: [ChatMessage] = []
    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Umi",
        category: "Conversation"
    )

    var exchanges: [Exchange] {
        let pairs = messages.indices.dropFirst().compactMap { index -> Exchange? in
            let question = messages[index - 1]
            let answer = messages[index]
            guard question.author == .user, answer.author == .umi, !answer.isFailureLine else { return nil }
            return Exchange(question: question.text, answer: answer.text)
        }
        return Array(pairs.suffix(Self.exchangesForBrain))
    }

    func addQuestion(_ text: String) -> ChatMessage.ID {
        let question = ChatMessage(id: UUID(), author: .user, text: text, time: .now, isFailureLine: false)
        messages.append(question)
        return question.id
    }

    func writeAnswer(_ text: String, to questionID: ChatMessage.ID) {
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, let index = messages.firstIndex(where: { $0.id == questionID }) else { return }
        let answerIndex = messages.index(after: index)
        if answerIndex < messages.endIndex, messages[answerIndex].author == .umi, !messages[answerIndex].isFailureLine {
            guard messages[answerIndex].text != answer else { return }
            messages[answerIndex].text = answer
        } else {
            let message = ChatMessage(id: UUID(), author: .umi, text: answer, time: .now, isFailureLine: false)
            messages.insert(message, at: answerIndex)
        }
    }

    func addFailureLine(_ line: String, under questionID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == questionID }) else { return }
        var lineIndex = messages.index(after: index)
        if lineIndex < messages.endIndex, messages[lineIndex].author == .umi {
            lineIndex = messages.index(after: lineIndex)
        }
        let message = ChatMessage(id: UUID(), author: .umi, text: line, time: .now, isFailureLine: true)
        messages.insert(message, at: lineIndex)
        logger.notice("A failure line shows under the typed question, for this run only")
    }

    func endAnswer(to questionID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == questionID }) else { return }
        let answerIndex = messages.index(after: index)
        guard answerIndex < messages.endIndex, messages[answerIndex].author == .umi else {
            messages.remove(at: index)
            logger.notice("No answer text arrived, so the exchange was not kept")
            return
        }
        guard !messages[answerIndex].isFailureLine else { return }
        let characters = messages[answerIndex].text.count
        let kept = messages.count
        logger.notice("Kept an exchange: \(characters, privacy: .public) answer characters")
        logger.notice("The chat holds \(kept, privacy: .public) messages")
    }
}
