import SwiftUI

struct MarkView: View {
    let place: MarkPlace

    var body: some View {
        switch place {
        case .ring(let center):
            MarkRing()
                .position(center)
        }
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
