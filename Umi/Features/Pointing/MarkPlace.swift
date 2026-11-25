import CoreGraphics

nonisolated enum MarkPlace: Sendable {
    static let ringDiameter = 34.0

    case ring(CGPoint)

    var kindName: String {
        switch self {
        case .ring: "a ring"
        }
    }

    var center: CGPoint {
        switch self {
        case .ring(let center): center
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
        }
    }

    func mapped(_ transform: (CGPoint) -> CGPoint) -> MarkPlace {
        switch self {
        case .ring(let center): .ring(transform(center))
        }
    }

    func edge(toward direction: CGVector, gap: Double) -> CGPoint {
        switch self {
        case .ring(let center):
            let reach = Self.ringDiameter / 2 + gap
            return CGPoint(x: center.x + direction.dx * reach, y: center.y + direction.dy * reach)
        }
    }
}
