import Foundation
import Observation
import OSLog

@Observable
final class Conversation {
    private static let exchangesForBrain = 20

    private(set) var messages: [ChatMessage] = []
    @ObservationIgnored private let file: ChatFile
    @ObservationIgnored private var saving: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Umi",
        category: "Conversation"
    )

    init(file: ChatFile) {
        self.file = file
    }

    var exchanges: [Exchange] {
        let pairs = messages.indices.dropFirst().compactMap { index -> Exchange? in
            let question = messages[index - 1]
            let answer = messages[index]
            guard question.author == .user, answer.author == .umi, !answer.isFailureLine else { return nil }
            return Exchange(question: question.text, answer: answer.text)
        }
        return Array(pairs.suffix(Self.exchangesForBrain))
    }

    // Runs once, before any question is taken, so no save can replace the file before it is read.
    func load() async {
        switch await file.read() {
        case .noFile:
            logger.notice("There is no saved chat yet")
        case .messages(let saved):
            messages = saved
            logger.notice("The saved chat was read: \(saved.count, privacy: .public) messages")
        case .setAside:
            logger.error("The saved chat could not be read: it was set aside as chat-unreadable.json")
            logger.notice("The chat starts empty")
        case .unreadable:
            logger.error("The saved chat could not be read nor set aside: the chat starts empty")
        }
    }

    func addQuestion(_ text: String, way: ChatMessage.Way) -> ChatMessage.ID {
        let question = ChatMessage(id: UUID(), author: .user, text: text, time: .now, way: way, isFailureLine: false)
        messages.append(question)
        save()
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
            let way = messages[index].way
            let message = ChatMessage(
                id: UUID(), author: .umi, text: answer, time: .now, way: way, isFailureLine: false
            )
            messages.insert(message, at: answerIndex)
        }
    }

    func addFailureLine(_ line: String, under questionID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == questionID }) else { return }
        var lineIndex = messages.index(after: index)
        if lineIndex < messages.endIndex, messages[lineIndex].author == .umi {
            lineIndex = messages.index(after: lineIndex)
        }
        let message = ChatMessage(id: UUID(), author: .umi, text: line, time: .now, way: .typed, isFailureLine: true)
        messages.insert(message, at: lineIndex)
        logger.notice("A failure line shows under the typed question, for this run only")
    }

    func endAnswer(to questionID: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == questionID }) else { return }
        let answerIndex = messages.index(after: index)
        guard answerIndex < messages.endIndex, messages[answerIndex].author == .umi else {
            messages.remove(at: index)
            save()
            logger.notice("No answer text arrived, so the exchange was not kept")
            return
        }
        guard !messages[answerIndex].isFailureLine else { return }
        save()
        let characters = messages[answerIndex].text.count
        let kept = messages.count
        logger.notice("Kept an exchange: \(characters, privacy: .public) answer characters")
        logger.notice("The chat holds \(kept, privacy: .public) messages")
    }

    func clear() {
        messages.removeAll()
        let previous = saving
        saving = Task { [file, logger] in
            await previous?.value
            do {
                try await file.clear()
                logger.notice("The saved chat was emptied, and no set-aside file is left")
            } catch {
                logger.error("The saved chat could not be emptied: \(Self.code(of: error), privacy: .public)")
            }
        }
        logger.notice("The chat was cleared")
    }

    // Waits for every save asked for so far, so a quit right after an answer still has it on disk.
    func saved() async {
        await saving?.value
    }

    // Failure lines are for this run only; they are never written.
    private func save() {
        let kept = messages.filter { !$0.isFailureLine }
        let previous = saving
        saving = Task { [file, logger] in
            await previous?.value
            do {
                try await file.write(kept)
            } catch {
                logger.error("The chat could not be saved: \(Self.code(of: error), privacy: .public)")
            }
        }
    }

    // Only the error's domain and code: its description can hold a path or the file's text.
    private nonisolated static func code(of error: any Error) -> String {
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
}
