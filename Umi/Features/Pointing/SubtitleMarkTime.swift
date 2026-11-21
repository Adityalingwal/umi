struct SubtitleMarkTime {
    // Decision 5 of #19: in a subtitle-only answer the mark stays until the last subtitle fades, and at least 4 s.
    private static let shortest = Duration.seconds(4)

    private var markedAt: ContinuousClock.Instant?
    private var subtitlesGoneAt: ContinuousClock.Instant?

    var clearAt: ContinuousClock.Instant? {
        guard let markedAt, let subtitlesGoneAt else { return nil }
        return max(markedAt + Self.shortest, subtitlesGoneAt)
    }

    mutating func marked(at instant: ContinuousClock.Instant) {
        markedAt = instant
    }

    mutating func subtitlesGo(at instant: ContinuousClock.Instant) {
        subtitlesGoneAt = instant
    }
}
