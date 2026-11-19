import SwiftUI

struct SubtitleView: View {
    @Environment(Subtitles.self) private var subtitles

    var body: some View {
        ZStack(alignment: .bottom) {
            if let line = subtitles.line {
                SubtitleLine(text: line)
                    .id(line)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.easeInOut(duration: 0.2), value: subtitles.line)
    }
}

private struct SubtitleLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.75), in: .rect(cornerRadius: 12, style: .continuous))
    }
}
