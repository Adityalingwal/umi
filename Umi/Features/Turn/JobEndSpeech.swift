import OSLog

// A job's end is said only once no one is speaking; the line takes the turn's one voice, so a new question cuts it.
final class JobEndSpeech {
    private static let checkInterval = Duration.milliseconds(200)

    private let speaker: Speaker
    private let parts: TurnParts
    private let board: Board
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var waiting: [String] = []
    private var speaking: Task<Void, Never>?

    init(speaker: Speaker, parts: TurnParts, board: Board) {
        self.speaker = speaker
        self.parts = parts
        self.board = board
    }

    private var isTurnOver: Bool {
        parts.hearing == nil && parts.speaking == nil && !board.isDrawing
    }

    func say(_ line: String) {
        waiting.append(line)
        if !isTurnOver {
            logger.notice("A job ended while a turn goes on: its line waits until the turn is over")
        }
        guard speaking == nil else { return }
        speaking = Task { [weak self] in
            await self?.sayWaitingLines()
        }
    }

    private func sayWaitingLines() async {
        defer { speaking = nil }
        while !waiting.isEmpty {
            while !isTurnOver {
                try? await Task.sleep(for: Self.checkInterval)
                guard !Task.isCancelled else { return }
            }
            await speak(waiting.removeFirst())
        }
    }

    private func speak(_ line: String) async {
        let voice: SpokenAnswer
        do {
            voice = try speaker.answer()
        } catch {
            logger.error("A job's line has no voice: \(StopReason.text(for: error), privacy: .public)")
            return
        }
        parts.speaking = voice
        voice.start { [logger] _ in
            logger.error("The voice failed while it said a job's line")
        }
        logger.notice("A job's line is spoken: \(line.count, privacy: .public) characters")
        voice.speak(line)
        voice.endText()
        for await _ in voice.events {}
        parts.release(voice)
    }
}
