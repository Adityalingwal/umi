import SwiftUI

struct ChatView: View {
    private static let newestID = "newest"
    private static let awayFromNewest = 40.0

    let jumpsToNewest: Bool
    @Environment(Conversation.self) private var conversation
    @State private var isAwayFromNewest = false

    var body: some View {
        if conversation.messages.isEmpty {
            Text("No messages yet")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(ChatGroup.groups(of: conversation.messages)) { group in
                            ChatGroupView(group: group)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    Color.clear
                        .frame(height: 0)
                        .id(Self.newestID)
                }
                .scrollIndicators(.never)
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                .textSelection(.enabled)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height - geometry.visibleRect.maxY > Self.awayFromNewest
                } action: { _, isAway in
                    isAwayFromNewest = isAway
                }
                .overlay(alignment: .bottomTrailing) {
                    if jumpsToNewest, isAwayFromNewest {
                        JumpToNewestButton {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(Self.newestID, anchor: .bottom)
                            }
                        }
                        .padding(12)
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: isAwayFromNewest)
            }
        }
    }
}

private struct JumpToNewestButton: View {
    let jump: () -> Void

    var body: some View {
        Button(action: jump) {
            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(Color(white: 0.25), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Jump to the newest message")
        .accessibilityLabel("Jump to the newest message")
    }
}
