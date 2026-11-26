import SwiftUI

struct NotchView: View {
    private static let motion = Animation.easeOut(duration: 0.2)

    let notchHeight: CGFloat
    let openWindow: () -> Void
    let toggleSettings: () -> Void
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
                    PanelTopRow(height: notchHeight, content: notch.panelContent, toggle: toggleSettings)
                    PanelContent(content: notch.panelContent, openWindow: openWindow)
                }
                .padding(.horizontal, NotchPlace.shoulder)
                .transition(.opacity)
            }
        }
        .clipShape(shape)
        .animation(Self.motion, value: notch.isOpen)
    }
}

// The row beside the hardware notch keeps the chat's width, so its button stays put while the panel widens.
private struct PanelTopRow: View {
    let height: CGFloat
    let content: HomeContent
    let toggle: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            switch content {
            case .chat: SettingsButton(open: toggle)
            case .settings: BackButton(back: toggle)
            }
        }
        .padding(.trailing, 12)
        .frame(width: NotchPlace.chatSize.width, height: height)
        .frame(maxWidth: .infinity)
    }
}

private struct PanelContent: View {
    let content: HomeContent
    let openWindow: () -> Void

    var body: some View {
        Group {
            switch content {
            case .chat:
                VStack(spacing: 0) {
                    ChatView(jumpsToNewest: false)
                    HStack(spacing: 8) {
                        AskRow(place: .panel)
                        OpenWindowButton(open: openWindow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            case .settings:
                SettingsView()
                    .padding(.bottom, 10)
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: content)
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
