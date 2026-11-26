import SwiftUI

struct ChatWindowView: View {
    @Environment(Notch.self) private var notch

    var body: some View {
        VStack(spacing: 0) {
            WindowTopRow(content: notch.windowContent)
            Group {
                switch notch.windowContent {
                case .chat: WindowChat()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity)
            .animation(.easeOut(duration: 0.15), value: notch.windowContent)
        }
        .frame(minWidth: 380, minHeight: 360)
        .background(Color.black)
    }
}

private struct WindowTopRow: View {
    let content: HomeContent
    @Environment(Notch.self) private var notch

    var body: some View {
        HStack {
            switch content {
            case .chat:
                Spacer(minLength: 0)
                SettingsButton { notch.showSettingsInWindow() }
            case .settings:
                BackButton { notch.showChatInWindow() }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }
}

private struct WindowChat: View {
    var body: some View {
        VStack(spacing: 0) {
            ChatView(jumpsToNewest: true)
            HStack(spacing: 8) {
                HoldToTalkHint()
                AskRow(place: .window)
            }
            .padding(12)
        }
    }
}

private struct HoldToTalkHint: View {
    var body: some View {
        Text("Hold right option to talk")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(height: AskRow.fieldHeight)
            .background(.white.opacity(0.1), in: Capsule())
            .fixedSize()
    }
}
