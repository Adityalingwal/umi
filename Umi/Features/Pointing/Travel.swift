import CoreGraphics
import Foundation

struct Travel {
    static let ringDiameter = 34.0

    private static let gapOutsideRing = 6.0
    private static let arrowLength = 22.0
    private static let bend = 0.15

    let target: CGPoint
    let duration: Duration

    private let start: CGPoint
    private let end: CGPoint
    private let bendPoint: CGPoint
    private let startDate: Date

    init(from start: CGPoint, to target: CGPoint, within bounds: CGRect, duration: Duration, startingAt date: Date) {
        self.start = start
        self.target = target
        self.duration = duration
        startDate = date
        end = Self.landing(beside: target, comingFrom: start, within: bounds)
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        bendPoint = CGPoint(
            x: middle.x + (end.y - start.y) * Self.bend,
            y: middle.y - (end.x - start.x) * Self.bend
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
        let eased = progress < 0.5 ? 4 * pow(progress, 3) : 1 - pow(-2 * progress + 2, 3) / 2
        let rest = 1 - eased
        return CGPoint(
            x: rest * rest * start.x + 2 * rest * eased * bendPoint.x + eased * eased * end.x,
            y: rest * rest * start.y + 2 * rest * eased * bendPoint.y + eased * eased * end.y
        )
    }

    func angle(at progress: Double) -> Double {
        let tip = tip(at: progress)
        return atan2(target.y - tip.y, target.x - tip.x)
    }

    private static func landing(beside target: CGPoint, comingFrom start: CGPoint, within bounds: CGRect) -> CGPoint {
        let away = CGVector(dx: start.x - target.x, dy: start.y - target.y)
        let length = hypot(away.dx, away.dy)
        let direction = length > 1 ? CGVector(dx: away.dx / length, dy: away.dy / length) : CGVector(dx: 0.7, dy: 0.7)
        let distance = ringDiameter / 2 + gapOutsideRing
        let safeArea = bounds.insetBy(dx: arrowLength, dy: arrowLength)
        let turns = [direction, direction.turnedQuarter, direction.turnedQuarter.turnedQuarter.turnedQuarter,
                     direction.turnedQuarter.turnedQuarter]
        let candidates = turns.map { CGPoint(x: target.x + $0.dx * distance, y: target.y + $0.dy * distance) }
        return candidates.first(where: safeArea.contains) ?? candidates[0]
    }
}

private extension CGVector {
    var turnedQuarter: CGVector {
        CGVector(dx: -dy, dy: dx)
    }
}
