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
            ReadAloudButton(isOn: notch.readsAloud) { notch.toggleReadAloud() }
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

private struct ReadAloudButton: View {
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.45))
                .frame(width: SendButton.size, height: SendButton.size)
                .background(.white.opacity(isOn ? 0.18 : 0.08), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Read aloud is on" : "Read aloud is off")
        .accessibilityLabel("Read aloud")
        .accessibilityValue(isOn ? "On" : "Off")
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}
