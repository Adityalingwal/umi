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
        }
    }

    // The line is drawn inside this frame, so a box cut at the screen's edge keeps its whole line there.
    private func drawnBox(around frame: CGRect) -> CGRect {
        let grown = frame.insetBy(dx: -MarkBox.outset, dy: -MarkBox.outset)
        let kept = grown.intersection(bounds)
        return kept.isNull || kept.isEmpty ? grown : kept
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
