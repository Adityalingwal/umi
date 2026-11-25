import CoreGraphics

struct AnswerMark {
    private static let ringReach = 40.0
    private static let boxReach = 8.0
    private static let strokeReach = 8.0

    let number: Int
    let place: MarkPlace
    let label: PointLabel?

    func isUnder(_ press: CGPoint) -> Bool {
        switch place {
        case .ring(let center):
            hypot(press.x - center.x, press.y - center.y) <= Self.ringReach
        case .box(let frame):
            frame.insetBy(dx: -Self.boxReach, dy: -Self.boxReach).contains(press)
        case .stroke(let start, let end):
            isOnStroke(press, from: start, to: end)
        }
    }

    // The marked thing is the line of text above the stroke. Screen points grow upward, so that text is at larger y:
    // a press counts from the reach under the stroke up to the top of the text.
    private func isOnStroke(_ press: CGPoint, from start: CGPoint, to end: CGPoint) -> Bool {
        let lift = MarkPlace.textAboveStroke - Self.strokeReach
        let raisedStart = CGPoint(x: start.x, y: start.y + lift)
        let raisedEnd = CGPoint(x: end.x, y: end.y + lift)
        return Self.distance(from: press, toLineFrom: start, to: end) <= Self.strokeReach
            || Self.distance(from: press, toLineFrom: raisedStart, to: raisedEnd) <= Self.strokeReach
    }

    private static func distance(from point: CGPoint, toLineFrom start: CGPoint, to end: CGPoint) -> Double {
        let line = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let lengthSquared = line.dx * line.dx + line.dy * line.dy
        let along = ((point.x - start.x) * line.dx + (point.y - start.y) * line.dy) / lengthSquared
        let share = min(1, max(0, along))
        return hypot(point.x - (start.x + line.dx * share), point.y - (start.y + line.dy * share))
    }
}
