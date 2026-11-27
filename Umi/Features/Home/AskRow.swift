import SwiftUI

struct AskRow: View {
    static let fieldHeight = 34.0

    let place: AskPlace
    @Environment(Notch.self) private var notch
    @FocusState private var isFieldFocused: Bool
    @State private var selection: TextSelection?

    var body: some View {
        @Bindable var notch = notch
        HStack(spacing: 6) {
            TextField(
                "Ask Umi…",
                text: $notch.draft,
                selection: $selection,
                prompt: Text("Ask Umi…").foregroundStyle(.white.opacity(0.4))
            )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($isFieldFocused)
                .onSubmit { notch.send(from: place) }
            ReadAloudButton(isOn: notch.readsAloud) { notch.toggleReadAloud(in: place) }
            SendButton(isEnabled: notch.canSend) { notch.send(from: place) }
        }
        .onChange(of: notch.isFieldWanted(in: place), initial: true) {
            guard notch.isFieldWanted(in: place) else { return }
            focusField()
            notch.fieldTookFocus(in: place)
        }
        .onChange(of: notch.draft) {
            guard isFieldFocused else { return }
            notch.fieldEdited(in: place)
        }
        .padding(.leading, 14)
        .padding(.trailing, (Self.fieldHeight - SendButton.size) / 2)
        .frame(height: Self.fieldHeight)
        .background(.white.opacity(0.1), in: Capsule())
    }

    // A field taking the focus selects its text; half a question goes on from its end instead.
    private func focusField() {
        isFieldFocused = true
        selection = TextSelection(insertionPoint: notch.draft.endIndex)
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
