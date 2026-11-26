import SwiftUI

struct ChatGroupView: View {
    let group: ChatGroup

    var body: some View {
        VStack(spacing: 6) {
            Text(group.timeText(now: .now, calendar: .current))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 6)
            ForEach(group.messages) { message in
                ChatBubble(message: message)
            }
        }
    }
}
