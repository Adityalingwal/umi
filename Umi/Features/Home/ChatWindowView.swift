import SwiftUI

struct ChatWindowView: View {
    var body: some View {
        VStack(spacing: 0) {
            ChatView(jumpsToNewest: true)
            HStack(spacing: 8) {
                HoldToTalkHint()
                AskRow(place: .window)
            }
            .padding(12)
        }
        .frame(minWidth: 380, minHeight: 360)
        .background(Color.black)
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
