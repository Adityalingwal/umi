import SwiftUI

struct CursorView: View {
    @Environment(UmiCursor.self) private var cursor

    var body: some View {
        ZStack {
            switch cursor.state {
            case .hidden:
                EmptyView()
            case .listening:
                CursorBadge { CursorWaveform() }
                    .transition(.appear)
            case .thinking:
                CursorBadge { CursorSpinner() }
                    .transition(.appear)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.12), value: cursor.state)
    }
}

private struct CursorBadge<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: 40, height: 22)
            .background(.black.opacity(0.75), in: .capsule)
    }
}

private struct CursorWaveform: View {
    private static let barCount = 5
    private static let lowestBar = 3.0
    private static let highestBar = 14.0

    @Environment(UmiCursor.self) private var cursor

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<Self.barCount, id: \.self) { bar in
                    Capsule()
                        .fill(.white)
                        .frame(width: 3, height: Self.height(ofBar: bar, at: time, level: cursor.level))
                }
            }
        }
        .accessibilityLabel("Listening")
    }

    private static func height(ofBar bar: Int, at time: TimeInterval, level: Double) -> Double {
        let wave = (sin(time * 9 + Double(bar) * 1.3) + 1) / 2
        let swing = 0.15 + 0.85 * level
        return lowestBar + (highestBar - lowestBar) * swing * wave
    }
}

private struct CursorSpinner: View {
    private static let turnsPerSecond = 1.1

    var body: some View {
        TimelineView(.animation) { timeline in
            let turns = timeline.date.timeIntervalSinceReferenceDate * Self.turnsPerSecond
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
        }
        .accessibilityLabel("Thinking")
    }
}

private extension AnyTransition {
    static let appear = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.8)),
        removal: .identity
    )
}
