import SwiftUI

struct SendButton: View {
    static let size = 24.0

    let isEnabled: Bool
    let send: () -> Void

    var body: some View {
        Button(action: send) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: Self.size, height: Self.size)
                .background(.white.opacity(isEnabled ? 0.95 : 0.3), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help("Send")
        .accessibilityLabel("Send")
        .animation(.easeOut(duration: 0.12), value: isEnabled)
    }
}
