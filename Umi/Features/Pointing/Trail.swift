import Foundation
import Observation

@Observable
final class Trail {
    // Both times are guesses; the design pass sets the final feel.
    static let partFade = 1.4
    static let releaseFade = 0.33

    private(set) var parts: [TrailPart] = []
    private(set) var releasedAt: Date?

    func paint(_ part: TrailPart) {
        parts.removeAll { part.paintedAt.timeIntervalSince($0.paintedAt) >= Self.partFade }
        parts.append(part)
    }

    func release(at time: Date) {
        releasedAt = time
    }

    func clear() {
        parts = []
        releasedAt = nil
    }

    func strength(of part: TrailPart, at time: Date) -> Double {
        let left = Self.share(left: time.timeIntervalSince(part.paintedAt), of: Self.partFade)
        let afterRelease = releasedAt.map { Self.share(left: time.timeIntervalSince($0), of: Self.releaseFade) } ?? 1
        return left * afterRelease
    }

    private static func share(left elapsed: TimeInterval, of fade: TimeInterval) -> Double {
        min(max(1 - elapsed / fade, 0), 1)
    }
}
