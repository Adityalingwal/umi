import CoreGraphics

nonisolated enum MarkPlace: Sendable {
    static let ringDiameter = 34.0
    static let strokeWidth = 5.0
    // A stroke lies just under its line of text; this is about how far that text reaches above it.
    static let textAboveStroke = 18.0
    static let dropBoxSide = 36.0

    case ring(CGPoint)
    case box(CGRect)
    case stroke(start: CGPoint, end: CGPoint)
    case drag(start: CGPoint, end: CGPoint)
    case shape(start: CGPoint, others: [CGPoint])

    var kindName: String {
        switch self {
        case .ring: "a ring"
        case .box: "a box"
        case .stroke: "a stroke"
        case .drag: "a drag"
        case .shape: "a free shape"
        }
    }

    var aimPoint: CGPoint {
        switch self {
        case .ring(let center):
            center
        case .box(let frame):
            CGPoint(x: frame.midX, y: frame.midY)
        case .stroke(let start, _), .drag(let start, _), .shape(let start, _):
            start
        }
    }

    var frame: CGRect {
        switch self {
        case .ring(let center):
            CGRect(square: Self.ringDiameter, around: center)
        case .box(let frame):
            frame
        case .stroke(let start, let end):
            CGRect(corner: start, opposite: end).insetBy(dx: -Self.strokeWidth / 2, dy: -Self.strokeWidth / 2)
        case .drag(let start, let end):
            CGRect(square: Self.ringDiameter, around: start).union(CGRect(square: Self.dropBoxSide, around: end))
        case .shape(let start, let others):
            CGRect(enclosing: [start] + others)
        }
    }

    var dropBox: CGRect? {
        guard case .drag(_, let end) = self else { return nil }
        return CGRect(square: Self.dropBoxSide, around: end)
    }

    // The arrow waits before a stroke's start, on the line's own path, so it covers none of the words,
    // and behind a drag's ring, away from the drop place, so it covers none of the drag's arrow.
    // At a free shape it waits outside its first point, away from the shape's middle.
    var landingDirection: CGVector? {
        switch self {
        case .ring, .box:
            return nil
        case .stroke(let start, let end), .drag(let start, let end):
            return Self.unit(from: end, to: start)
        case .shape(let start, _):
            return Self.unit(from: CGPoint(x: frame.midX, y: frame.midY), to: start)
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
        case .stroke(let start, let end):
            .stroke(start: transform(start), end: transform(end))
        case .drag(let start, let end):
            .drag(start: transform(start), end: transform(end))
        case .shape(let start, let others):
            .shape(start: transform(start), others: others.map(transform))
        }
    }

    func edge(toward direction: CGVector, gap: Double) -> CGPoint {
        let reach = switch self {
        case .ring, .drag:
            Self.ringDiameter / 2 + gap
        case .box(let frame):
            min(
                Self.reach(frame.width / 2 + gap, along: direction.dx),
                Self.reach(frame.height / 2 + gap, along: direction.dy)
            )
        case .stroke, .shape:
            gap
        }
        return CGPoint(x: aimPoint.x + direction.dx * reach, y: aimPoint.y + direction.dy * reach)
    }

    private static func unit(from origin: CGPoint, to point: CGPoint) -> CGVector? {
        let away = CGVector(dx: point.x - origin.x, dy: point.y - origin.y)
        let length = hypot(away.dx, away.dy)
        guard length > 0.5 else { return nil }
        return CGVector(dx: away.dx / length, dy: away.dy / length)
    }

    private static func reach(_ halfSide: Double, along step: Double) -> Double {
        abs(step) > 0.000_001 ? halfSide / abs(step) : .infinity
    }
}

nonisolated extension CGRect {
    init(square side: Double, around center: CGPoint) {
        self.init(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    init(corner: CGPoint, opposite: CGPoint) {
        self.init(
            x: min(corner.x, opposite.x),
            y: min(corner.y, opposite.y),
            width: abs(opposite.x - corner.x),
            height: abs(opposite.y - corner.y)
        )
    }

    init(enclosing points: [CGPoint]) {
        let across = points.map(\.x)
        let down = points.map(\.y)
        self.init(
            corner: CGPoint(x: across.min() ?? 0, y: down.min() ?? 0),
            opposite: CGPoint(x: across.max() ?? 0, y: down.max() ?? 0)
        )
    }
}
