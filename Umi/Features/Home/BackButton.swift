import SwiftUI

struct BackButton: View {
    let back: () -> Void

    var body: some View {
        Button(action: back) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                Text("Back")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 9)
            .frame(height: SettingsButton.size)
            .background(.white.opacity(0.1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Back to the chat")
        .accessibilityLabel("Back")
    }
}
