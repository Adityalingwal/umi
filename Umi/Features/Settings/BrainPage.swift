import SwiftUI

struct BrainPage: View {
    @Environment(UmiSettings.self) private var settings

    var body: some View {
        let brains = settings.brains
        SettingsPageLayout(page: .brain) {
            SettingsGroup {
                ForEach(BrainKind.allCases, id: \.self) { kind in
                    BrainOptionRow(
                        title: kind.title,
                        hint: brains.hint(for: kind),
                        isChosen: brains.choice == kind,
                        isEnabled: brains.isEnabled(kind)
                    ) {
                        brains.choose(kind)
                    }
                }
            }
        }
        .task {
            brains.refresh()
        }
    }
}

private struct BrainOptionRow: View {
    let title: String
    let hint: String?
    let isChosen: Bool
    let isEnabled: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            SettingsRow(title: title, detail: hint) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isChosen ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(title)
        .accessibilityValue(isChosen ? "Chosen" : "Not chosen")
        .accessibilityHint(hint ?? "")
        .animation(.easeOut(duration: 0.12), value: isChosen)
    }
}
