import OSLog

struct FailureLines {
    private let conversation: Conversation
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    // False when a spoken question's failure has no line, so the answer fails with the fail mark instead.
    func speak(for error: any Error, by voice: SpokenAnswer, under typedQuestion: ChatMessage.ID?) -> Bool {
        let reason = StopReason.text(for: error)
        guard let typedQuestion else {
            guard let line = UmiLine.failure(error) else { return false }
            logger.error("The question stopped: \(reason, privacy: .public)")
            voice.speak(line)
            voice.endText()
            return true
        }
        let line = UmiLine.chatFailure(error)
        logger.error("The typed question stopped: \(reason, privacy: .public)")
        conversation.addFailureLine(line, under: typedQuestion)
        voice.speak(line)
        voice.endText()
        return true
    }

    func showWithoutVoice(_ error: any Error, under typedQuestion: ChatMessage.ID) {
        logger.error("The typed question stopped with no voice: \(StopReason.text(for: error), privacy: .public)")
        conversation.addFailureLine(UmiLine.chatFailure(error), under: typedQuestion)
    }
}
