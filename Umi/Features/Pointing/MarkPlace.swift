import CoreGraphics

nonisolated enum MarkPlace: Sendable {
    static let ringDiameter = 34.0

    case ring(CGPoint)
    case box(CGRect)

    var kindName: String {
        switch self {
        case .ring: "a ring"
        case .box: "a box"
        }
    }

    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
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
        }
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
        }
        return CGPoint(x: center.x + direction.dx * reach, y: center.y + direction.dy * reach)
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
