import SwiftUI

struct ChatView: View {
    @Environment(Conversation.self) private var conversation

    var body: some View {
        if conversation.messages.isEmpty {
            Text("No messages yet")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(ChatGroup.groups(of: conversation.messages)) { group in
                        ChatGroupView(group: group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .textSelection(.enabled)
        }
    }
}
