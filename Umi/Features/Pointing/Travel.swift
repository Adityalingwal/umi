import CoreGraphics
import Foundation

struct Travel {
    private static let gapOutsideMark = 6.0
    private static let arrowLength = 22.0
    private static let bend = 0.15
    private static let turningShare = 0.25

    let duration: Duration
    let arrowTip: CGPoint
    let isGoingHome: Bool

    private let target: CGPoint
    private let start: CGPoint
    private let bendPoint: CGPoint
    private let startDate: Date
    private let startAngle: Double?

    init(
        from start: CGPoint,
        turningFrom startAngle: Double?,
        toMark place: MarkPlace,
        within bounds: CGRect,
        duration: Duration,
        startingAt date: Date
    ) {
        self.init(
            from: start,
            turningFrom: startAngle,
            to: place.center,
            arrowTip: Self.landing(beside: place, comingFrom: start, within: bounds),
            isGoingHome: false,
            duration: duration,
            startingAt: date
        )
    }

    init(
        from start: CGPoint,
        turningFrom startAngle: Double?,
        homeTo rest: CGPoint,
        duration: Duration,
        startingAt date: Date
    ) {
        self.init(
            from: start,
            turningFrom: startAngle,
            to: rest,
            arrowTip: rest,
            isGoingHome: true,
            duration: duration,
            startingAt: date
        )
    }

    private init(
        from start: CGPoint,
        turningFrom startAngle: Double?,
        to target: CGPoint,
        arrowTip: CGPoint,
        isGoingHome: Bool,
        duration: Duration,
        startingAt date: Date
    ) {
        self.start = start
        self.startAngle = startAngle
        self.target = target
        self.arrowTip = arrowTip
        self.isGoingHome = isGoingHome
        self.duration = duration
        startDate = date
        let middle = CGPoint(x: (start.x + arrowTip.x) / 2, y: (start.y + arrowTip.y) / 2)
        bendPoint = CGPoint(
            x: middle.x + (arrowTip.y - start.y) * Self.bend,
            y: middle.y - (arrowTip.x - start.x) * Self.bend
        )
    }

    static func usualDuration(from start: CGPoint, to target: CGPoint) -> Duration {
        let distance = hypot(target.x - start.x, target.y - start.y)
        return .seconds(min(0.7, max(0.3, 0.25 + distance / 2_500)))
    }

    func progress(at date: Date) -> Double {
        let seconds = duration / .seconds(1)
        guard seconds > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(startDate) / seconds))
    }

    func tip(at progress: Double) -> CGPoint {
        let eased = Self.eased(progress)
        let rest = 1 - eased
        return CGPoint(
            x: rest * rest * start.x + 2 * rest * eased * bendPoint.x + eased * eased * arrowTip.x,
            y: rest * rest * start.y + 2 * rest * eased * bendPoint.y + eased * eased * arrowTip.y
        )
    }

    func angle(at progress: Double) -> Double {
        let heading = heading(at: progress)
        guard let startAngle, progress < Self.turningShare else { return heading }
        return Self.turn(from: startAngle, to: heading, share: progress / Self.turningShare)
    }

    // A flight that starts inside its mark moves away from the mark's centre, so it steers along its path
    // and turns to face the mark over its last quarter.
    private func heading(at progress: Double) -> Double {
        if isGoingHome {
            return headingAlongPath(at: progress)
        }
        guard hypot(start.x - target.x, start.y - target.y) < hypot(arrowTip.x - target.x, arrowTip.y - target.y) else {
            return headingToTarget(at: progress)
        }
        let arriving = 1 - Self.turningShare
        guard progress > arriving else { return headingAlongPath(at: progress) }
        let share = (progress - arriving) / Self.turningShare
        return Self.turn(from: headingAlongPath(at: progress), to: headingToTarget(at: progress), share: share)
    }

    private static func turn(from start: Double, to end: Double, share: Double) -> Double {
        let turn = end - start
        return start + atan2(sin(turn), cos(turn)) * share
    }

    private func headingToTarget(at progress: Double) -> Double {
        let tip = tip(at: progress)
        return atan2(target.y - tip.y, target.x - tip.x)
    }

    private func headingAlongPath(at progress: Double) -> Double {
        let eased = Self.eased(progress)
        let alongX = (1 - eased) * (bendPoint.x - start.x) + eased * (arrowTip.x - bendPoint.x)
        let alongY = (1 - eased) * (bendPoint.y - start.y) + eased * (arrowTip.y - bendPoint.y)
        guard hypot(alongX, alongY) > 0.001 else { return startAngle ?? 0 }
        return atan2(alongY, alongX)
    }

    private static func eased(_ progress: Double) -> Double {
        progress < 0.5 ? 4 * pow(progress, 3) : 1 - pow(-2 * progress + 2, 3) / 2
    }

    private static func landing(beside place: MarkPlace, comingFrom start: CGPoint, within bounds: CGRect) -> CGPoint {
        let target = place.center
        let away = CGVector(dx: start.x - target.x, dy: start.y - target.y)
        let length = hypot(away.dx, away.dy)
        let direction = length > 1 ? CGVector(dx: away.dx / length, dy: away.dy / length) : CGVector(dx: 0.7, dy: 0.7)
        let safeArea = bounds.insetBy(dx: arrowLength, dy: arrowLength)
        let turns = [direction, direction.turnedQuarter, direction.turnedQuarter.turnedQuarter.turnedQuarter,
                     direction.turnedQuarter.turnedQuarter]
        let candidates = turns.map { place.edge(toward: $0, gap: gapOutsideMark) }
        let fallback = candidates[0]
        return candidates.first(where: safeArea.contains) ?? CGPoint(
            x: min(max(fallback.x, safeArea.minX), safeArea.maxX),
            y: min(max(fallback.y, safeArea.minY), safeArea.maxY)
        )
    }
}

private extension CGVector {
    var turnedQuarter: CGVector {
        CGVector(dx: -dy, dy: dx)
    }
}
