import SwiftUI

struct CopyButton: View {
    private static let shownFor = Duration.seconds(1.5)

    let text: String
    @Environment(Notch.self) private var notch
    @State private var isCopied = false

    var body: some View {
        Button {
            notch.copy(text)
            isCopied = true
        } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(isCopied ? 0.8 : 0.45))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Copy")
        .accessibilityLabel("Copy answer")
        .padding(.leading, 4)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: Self.shownFor)
            guard !Task.isCancelled else { return }
            isCopied = false
        }
    }
}
