import SwiftUI

struct SettingsButton: View {
    static let size = 22.0

    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: Self.size, height: Self.size)
                .background(.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Settings")
        .accessibilityLabel("Settings")
    }
}
