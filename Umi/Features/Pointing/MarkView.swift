import SwiftUI

struct MarkView: View {
    let place: MarkPlace
    let bounds: CGRect

    init(place: MarkPlace, within bounds: CGRect) {
        self.place = place
        self.bounds = bounds
    }

    var body: some View {
        switch place {
        case .ring(let center):
            MarkRing()
                .position(center)
        case .box(let frame):
            let drawn = drawnBox(around: frame)
            MarkBox()
                .frame(width: drawn.width, height: drawn.height)
                .position(x: drawn.midX, y: drawn.midY)
        case .stroke(let start, let end):
            let ends = [start, end].map(keptOnScreen)
            let drawn = CGRect(corner: ends[0], opposite: ends[1])
                .insetBy(dx: -MarkPlace.strokeWidth / 2, dy: -MarkPlace.strokeWidth / 2)
            MarkStroke(start: ends[0], end: ends[1], origin: drawn.origin)
                .frame(width: drawn.width, height: drawn.height)
                .position(x: drawn.midX, y: drawn.midY)
        case .drag(let start, let end):
            let drawn = place.frame.insetBy(dx: -MarkPlace.strokeWidth, dy: -MarkPlace.strokeWidth)
            MarkDrag(start: start, end: end, origin: drawn.origin)
                .frame(width: drawn.width, height: drawn.height)
                .position(x: drawn.midX, y: drawn.midY)
        }
    }

    // The line is drawn inside this frame, so a box cut at the screen's edge keeps its whole line there.
    private func drawnBox(around frame: CGRect) -> CGRect {
        let grown = frame.insetBy(dx: -MarkBox.outset, dy: -MarkBox.outset)
        let kept = grown.intersection(bounds)
        return kept.isNull || kept.isEmpty ? grown : kept
    }

    private func keptOnScreen(_ point: CGPoint) -> CGPoint {
        let inside = bounds.insetBy(dx: MarkPlace.strokeWidth / 2, dy: MarkPlace.strokeWidth / 2)
        return CGPoint(x: min(max(point.x, inside.minX), inside.maxX), y: min(max(point.y, inside.minY), inside.maxY))
    }
}

private struct MarkRing: View {
    @State private var hasPulsed = false

    var body: some View {
        ZStack {
            RingStroke()
                .scaleEffect(hasPulsed ? 1.8 : 1)
                .opacity(hasPulsed ? 0 : 0.9)
            RingStroke()
        }
        .frame(width: MarkPlace.ringDiameter, height: MarkPlace.ringDiameter)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasPulsed = true
            }
        }
    }
}

private struct MarkBox: View {
    static let outset = 3.0

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(.black.opacity(0.55), lineWidth: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .inset(by: 1)
                    .strokeBorder(.white, lineWidth: 3)
            )
            .accessibilityHidden(true)
    }
}

private struct MarkStroke: View {
    let start: CGPoint
    let end: CGPoint
    let origin: CGPoint

    var body: some View {
        let line = StrokeLine(
            start: CGPoint(x: start.x - origin.x, y: start.y - origin.y),
            end: CGPoint(x: end.x - origin.x, y: end.y - origin.y)
        )
        ZStack {
            line.stroke(.black.opacity(0.55), style: StrokeStyle(lineWidth: MarkPlace.strokeWidth, lineCap: .round))
            line.stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}

private struct MarkDrag: View {
    let start: CGPoint
    let end: CGPoint
    let origin: CGPoint

    var body: some View {
        let ring = CGPoint(x: start.x - origin.x, y: start.y - origin.y)
        let drop = CGPoint(x: end.x - origin.x, y: end.y - origin.y)
        let shaft = DragShaft(start: ring, end: drop)
        ZStack {
            shaft.stroke(.black.opacity(0.55), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            shaft.stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            MarkRing()
                .position(ring)
            MarkBox()
                .frame(width: MarkPlace.dropBoxSide, height: MarkPlace.dropBoxSide)
                .position(drop)
        }
        .accessibilityHidden(true)
    }
}

// The arrow runs from the ring's edge to the drop box's edge; when they are too close for it, only the two show.
private nonisolated struct DragShaft: Shape {
    private static let gap = 4.0
    private static let headLength = 10.0
    private static let headSpread = 0.5

    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        let length = hypot(end.x - start.x, end.y - start.y)
        let along = CGVector(dx: (end.x - start.x) / length, dy: (end.y - start.y) / length)
        let fromStart = MarkPlace.ringDiameter / 2 + Self.gap
        let fromEnd = MarkPlace.dropBoxSide / 2 / max(abs(along.dx), abs(along.dy)) + Self.gap
        var path = Path()
        guard length - fromStart - fromEnd > Self.headLength else { return path }
        let tail = CGPoint(x: start.x + along.dx * fromStart, y: start.y + along.dy * fromStart)
        let tip = CGPoint(x: end.x - along.dx * fromEnd, y: end.y - along.dy * fromEnd)
        let back = atan2(-along.dy, -along.dx)
        path.move(to: tail)
        path.addLine(to: tip)
        for side in [-Self.headSpread, Self.headSpread] {
            path.move(to: tip)
            path.addLine(to: CGPoint(
                x: tip.x + cos(back + side) * Self.headLength,
                y: tip.y + sin(back + side) * Self.headLength
            ))
        }
        return path
    }
}

private nonisolated struct StrokeLine: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct RingStroke: View {
    var body: some View {
        Circle()
            .strokeBorder(.black.opacity(0.55), lineWidth: 5)
            .overlay(
                Circle()
                    .inset(by: 1)
                    .strokeBorder(.white, lineWidth: 3)
            )
    }
}
