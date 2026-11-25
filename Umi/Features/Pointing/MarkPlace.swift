import CoreGraphics

nonisolated enum MarkPlace: Sendable {
    static let ringDiameter = 34.0
    static let strokeWidth = 5.0

    case ring(CGPoint)
    case box(CGRect)
    case stroke(start: CGPoint, end: CGPoint)

    var kindName: String {
        switch self {
        case .ring: "a ring"
        case .box: "a box"
        case .stroke: "a stroke"
        }
    }

    var aimPoint: CGPoint {
        switch self {
        case .ring(let center):
            center
        case .box(let frame):
            CGPoint(x: frame.midX, y: frame.midY)
        case .stroke(let start, _):
            start
        }
    }

    var frame: CGRect {
        switch self {
        case .ring(let center):
            CGRect(
                x: center.x - Self.ringDiameter / 2,
                y: center.y - Self.ringDiameter / 2,
                width: Self.ringDiameter,
                height: Self.ringDiameter
            )
        case .box(let frame):
            frame
        case .stroke(let start, let end):
            CGRect(corner: start, opposite: end).insetBy(dx: -Self.strokeWidth / 2, dy: -Self.strokeWidth / 2)
        }
    }

    // The arrow waits before a stroke's start, on the line's own path, so it covers none of the words.
    var landingDirection: CGVector? {
        guard case .stroke(let start, let end) = self else { return nil }
        let away = CGVector(dx: start.x - end.x, dy: start.y - end.y)
        let length = hypot(away.dx, away.dy)
        return CGVector(dx: away.dx / length, dy: away.dy / length)
    }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> MarkPlace {
        switch self {
        case .ring(let center):
            .ring(transform(center))
        case .box(let frame):
            .box(CGRect(
                corner: transform(CGPoint(x: frame.minX, y: frame.minY)),
                opposite: transform(CGPoint(x: frame.maxX, y: frame.maxY))
            ))
        case .stroke(let start, let end):
            .stroke(start: transform(start), end: transform(end))
        }
    }

    func edge(toward direction: CGVector, gap: Double) -> CGPoint {
        let reach = switch self {
        case .ring:
            Self.ringDiameter / 2 + gap
        case .box(let frame):
            min(
                Self.reach(frame.width / 2 + gap, along: direction.dx),
                Self.reach(frame.height / 2 + gap, along: direction.dy)
            )
        case .stroke:
            gap
        }
        return CGPoint(x: aimPoint.x + direction.dx * reach, y: aimPoint.y + direction.dy * reach)
    }

    private static func reach(_ halfSide: Double, along step: Double) -> Double {
        abs(step) > 0.000_001 ? halfSide / abs(step) : .infinity
    }
}

nonisolated extension CGRect {
    init(corner: CGPoint, opposite: CGPoint) {
        self.init(
            x: min(corner.x, opposite.x),
            y: min(corner.y, opposite.y),
            width: abs(opposite.x - corner.x),
            height: abs(opposite.y - corner.y)
        )
    }
}
