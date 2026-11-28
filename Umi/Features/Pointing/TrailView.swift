import SwiftUI

struct TrailView: View {
    private static let colour = Color(red: 1, green: 0.25, blue: 0.25)
    private static let alpha = 0.45
    private static let band = StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)

    @Environment(Trail.self) private var trail

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: trail.parts.isEmpty)) { context in
            Canvas { canvas, _ in
                // Each part replaces what is under it, so the joins of a see-through band do not darken.
                canvas.blendMode = .copy
                for part in trail.parts {
                    let strength = trail.strength(of: part, at: context.date)
                    guard strength > 0 else { continue }
                    var line = Path()
                    line.move(to: part.start)
                    line.addLine(to: part.end)
                    canvas.stroke(line, with: .color(Self.colour.opacity(Self.alpha * strength)), style: Self.band)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
