import SwiftUI

struct ChatBubble: View {
    private static let questionColor = Color(red: 0.70, green: 0.85, blue: 1.0)
    private static let answerColor = Color(white: 0.19)
    private static let roomBeside = 56.0

    let message: ChatMessage

    var body: some View {
        switch message.author {
        case .user:
            HStack {
                Spacer(minLength: Self.roomBeside)
                bubble(background: Self.questionColor, text: .black)
            }
        case .umi:
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    bubble(background: Self.answerColor, text: .white)
                    CopyButton(text: message.text)
                }
                Spacer(minLength: Self.roomBeside)
            }
        }
    }

    private func bubble(background: Color, text: Color) -> some View {
        Text(message.text)
            .font(.system(size: 13))
            .foregroundStyle(text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
