import SwiftUI

// The hardware notch hides the middle, so the word sits on its left and its sign on its right.
struct NotchWordView: View {
    let word: NotchWord
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .frame(width: word.wing)
            Spacer(minLength: 0)
            NotchSign(word: word)
                .frame(width: word.wing)
        }
        .padding(.horizontal, NotchPlace.shoulder)
        .frame(height: height)
        .background(alignment: .bottom) {
            if word == .working {
                LinearGradient(colors: [.clear, .green.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    .frame(height: height / 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch word {
        case .working: "Working"
        case .done: "Done"
        case .didNotFinish: "Didn't finish"
        }
    }
}

private struct NotchSign: View {
    let word: NotchWord

    var body: some View {
        switch word {
        case .working:
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
                .symbolEffect(.variableColor.iterative, options: .repeating)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        case .didNotFinish:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }
}
