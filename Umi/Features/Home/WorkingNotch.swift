import SwiftUI

// The hardware notch hides the middle, so the word sits on its left and the moving dots on its right.
struct WorkingNotch: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("Working")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: NotchPlace.workingWing)
            Spacer(minLength: 0)
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .frame(width: NotchPlace.workingWing)
        }
        .padding(.horizontal, NotchPlace.shoulder)
        .frame(height: height)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .green.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                .frame(height: height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Working")
    }
}
