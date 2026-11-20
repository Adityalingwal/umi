import OSLog

struct AnswerReader {
    private let voice: SpokenAnswer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var tags = PointTagParser()
    private var splitter = SentenceSplitter()

    init(voice: SpokenAnswer) {
        self.voice = voice
    }

    mutating func read(_ answer: AsyncThrowingStream<String, any Error>) async throws {
        for try await piece in answer {
            for part in tags.add(piece) {
                read(part)
            }
        }
        try Task.checkCancellation()
        finish()
    }

    private mutating func finish() {
        for part in tags.finish() {
            read(part)
        }
        if let sentence = splitter.flush() {
            speak(sentence)
        }
        voice.endText()
    }

    private mutating func read(_ part: PointTagParser.Part) {
        switch part {
        case .text(let text):
            for sentence in splitter.add(text) {
                speak(sentence)
            }
        case .nameStart:
            splitter.markName()
        case .dropped(let problem):
            logger.notice("Location data was dropped: \(String(describing: problem), privacy: .public)")
        }
    }

    private func speak(_ sentence: SentenceSplitter.Sentence) {
        voice.speak(sentence.text, nameStart: sentence.nameStart)
    }
}
