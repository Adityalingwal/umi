import SwiftUI

struct PointerView: View {
    @Environment(PointerOverlay.self) private var overlay

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(overlay.marks) { mark in
                MarkRing()
                    .position(mark.target)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
            MarkLabels(marks: overlay.marks)
            if let travel = overlay.travel {
                TravellingArrow(travel: travel, isLanded: overlay.isLanded)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeOut(duration: 0.15), value: overlay.marks.count)
        .animation(.easeOut(duration: 0.15), value: overlay.travel == nil)
    }
}

private struct TravellingArrow: View {
    let travel: Travel
    let isLanded: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: isLanded)) { context in
            let progress = isLanded ? 1 : travel.progress(at: context.date)
            UmiArrow()
                .rotationEffect(.radians(travel.angle(at: progress)))
                .position(travel.tip(at: progress))
        }
    }
}

private struct UmiArrow: View {
    var body: some View {
        ZStack {
            ArrowShape()
                .fill(.white)
            ArrowShape()
                .stroke(.black.opacity(0.6), style: StrokeStyle(lineWidth: 1.25, lineJoin: .round))
        }
        .frame(width: 48, height: 48)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

private nonisolated struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 20, y: tip.y - 9))
        path.addLine(to: CGPoint(x: tip.x - 14, y: tip.y))
        path.addLine(to: CGPoint(x: tip.x - 20, y: tip.y + 9))
        path.closeSubpath()
        return path
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
        .frame(width: Travel.ringDiameter, height: Travel.ringDiameter)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasPulsed = true
            }
        }
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
