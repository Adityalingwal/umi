import OSLog

struct VoiceFollower {
    private let subtitles: Subtitles
    private let hideCursor: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")

    init(subtitles: Subtitles, hideCursor: @escaping () -> Void) {
        self.subtitles = subtitles
        self.hideCursor = hideCursor
    }

    func follow(_ voice: SpokenAnswer, pointing: Pointing?) async {
        for await event in voice.events {
            guard !Task.isCancelled else { return }
            switch event {
            case .show(let text):
                hideCursor()
                subtitles.show(text)
            case .nameComing(let delay):
                pointing?.nameComing(after: delay)
            case .nameStarted:
                pointing?.nameStarted()
            case .nameLineEnded:
                pointing?.nameLineEnded()
            case .nameShown:
                pointing?.nameShown()
            case .voiceFailed:
                pointing?.voiceFailed()
            case .finished:
                hideCursor()
                subtitles.finish()
                pointing?.answerEnded(subtitlesLingerFor: Subtitles.lingerAfterEnd)
                logger.notice("Answer finished")
            }
        }
    }
}
