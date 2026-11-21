import SwiftUI

struct BoardView: View {
    @Environment(BoardContent.self) private var content

    var body: some View {
        ZStack {
            BoardPaper.color
            TimelineView(.explicit(BoardPainter.frameDates(for: content.marks, after: .now))) { timeline in
                Canvas { context, size in
                    BoardPainter(size: size).draw(content.marks, in: context, at: timeline.date)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(content.summary)
            if content.isWaiting {
                DrawingStatus()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: content.isWaiting)
    }
}

enum BoardPaper {
    static let color = Color(red: 0.992, green: 0.988, blue: 0.976)
}

private struct DrawingStatus: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Drawing…")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BoardInk.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white, in: .capsule)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }
}
