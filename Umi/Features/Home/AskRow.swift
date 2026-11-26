import SwiftUI

struct AskRow: View {
    private static let fieldHeight = 34.0

    @Environment(Notch.self) private var notch

    var body: some View {
        @Bindable var notch = notch
        HStack(spacing: 6) {
            TextField("Ask Umi…", text: $notch.draft, prompt: Text("Ask Umi…").foregroundStyle(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .onSubmit { notch.send() }
            SendButton(isEnabled: notch.canSend) { notch.send() }
        }
        .padding(.leading, 14)
        .padding(.trailing, (Self.fieldHeight - SendButton.size) / 2)
        .frame(height: Self.fieldHeight)
        .background(.white.opacity(0.1), in: Capsule())
    }
}

private struct SendButton: View {
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
