nonisolated struct PointLabel: Equatable, Sendable {
    private static let longest = 40

    let text: String

    init?(_ written: String) {
        let words = written.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !words.isEmpty else { return nil }
        guard words.count > Self.longest else {
            text = words
            return
        }
        let kept = words.prefix(Self.longest - 1)
        text = String(kept.reversed().drop(while: \.isWhitespace).reversed()) + "…"
    }
}
