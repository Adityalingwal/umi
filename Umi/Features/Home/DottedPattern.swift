import SwiftUI

struct DottedPattern: View {
    private static let spacing = 9.0
    private static let dotSize = 1.2

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            for left in stride(from: Self.spacing / 2, to: size.width, by: Self.spacing) {
                for top in stride(from: Self.spacing / 2, to: size.height, by: Self.spacing) {
                    dots.addEllipse(in: CGRect(x: left, y: top, width: Self.dotSize, height: Self.dotSize))
                }
            }
            context.fill(dots, with: .color(.white.opacity(0.07)))
        }
        .allowsHitTesting(false)
    }
}
