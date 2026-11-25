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
