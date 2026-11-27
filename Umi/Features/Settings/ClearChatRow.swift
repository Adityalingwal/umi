import SwiftUI

struct ClearChatRow: View {
    private enum Step {
        case ready
        case asking
        case cleared
    }

    @Environment(UmiSettings.self) private var settings
    @State private var step = Step.ready

    var body: some View {
        SettingsRow(title: "Clear chat", detail: detail) {
            switch step {
            case .ready, .cleared:
                RowButton(title: "Clear…", label: "Clear chat") {
                    step = .asking
                }
            case .asking:
                HStack(spacing: 6) {
                    RowButton(title: "Cancel", label: "Keep the chat") {
                        step = .ready
                    }
                    RowButton(title: "Clear", label: "Clear the chat") {
                        settings.clearChat()
                        step = .cleared
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: step)
    }

    private var detail: String? {
        switch step {
        case .ready: nil
        case .asking: "Every message is deleted from this Mac. This cannot be undone."
        case .cleared: "The chat is empty."
        }
    }
}
