import CoreGraphics

nonisolated extension CGRect {
    func shareOfLine(from start: CGPoint, to end: CGPoint) -> ClosedRange<Double>? {
        let step = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let limits = [
            (-step.dx, start.x - minX), (step.dx, maxX - start.x),
            (-step.dy, start.y - minY), (step.dy, maxY - start.y)
        ]
        var enter = 0.0
        var leave = 1.0
        for (towardEdge, room) in limits {
            if towardEdge == 0 {
                guard room >= 0 else { return nil }
            } else if towardEdge < 0 {
                enter = max(enter, room / towardEdge)
            } else {
                leave = min(leave, room / towardEdge)
            }
        }
        return enter < leave ? enter...leave : nil
    }
}
