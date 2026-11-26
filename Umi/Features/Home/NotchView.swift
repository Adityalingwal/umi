import SwiftUI

struct NotchView: View {
    private static let motion = Animation.easeOut(duration: 0.2)

    let notchHeight: CGFloat
    let openWindow: () -> Void
    @Environment(Notch.self) private var notch

    var body: some View {
        let shape = NotchShape(
            shoulder: NotchPlace.shoulder,
            bottomRadius: notch.isOpen ? NotchPlace.openBottomRadius : NotchPlace.restBottomRadius
        )
        ZStack(alignment: .top) {
            Color.black
            if notch.isOpen {
                DottedPattern()
                VStack(spacing: 0) {
                    ChatView(jumpsToNewest: false)
                    HStack(spacing: 8) {
                        AskRow(place: .panel)
                        OpenWindowButton(open: openWindow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .padding(.top, notchHeight)
                .padding(.horizontal, NotchPlace.shoulder)
                .transition(.opacity)
            }
        }
        .clipShape(shape)
        .animation(Self.motion, value: notch.isOpen)
    }
}

private struct OpenWindowButton: View {
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: AskRow.fieldHeight, height: AskRow.fieldHeight)
                .background(.white.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Open in a window")
        .accessibilityLabel("Open in a window")
    }
}
