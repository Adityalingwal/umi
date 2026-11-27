import SwiftUI

// One Open control per file the job made; a long list scrolls inside the card.
struct JobFileList: View {
    private static let visibleRows = 4
    private static let rowHeight = 24.0

    let files: [JobFile]
    let open: (JobFile) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(files) { file in
                    JobFileRow(file: file) { open(file) }
                }
            }
        }
        .scrollIndicators(.never)
        .frame(height: Double(min(files.count, Self.visibleRows)) * Self.rowHeight)
    }
}

private struct JobFileRow: View {
    let file: JobFile
    let open: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: file.kind == .document ? "doc.text" : "doc")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
            Text(file.name)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button(action: open) {
                Text("Open")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 9)
                    .frame(height: 20)
                    .background(.white.opacity(0.12), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(file.kind == .document ? "Open \(file.name)" : "Show \(file.name) in Finder")
            .accessibilityLabel("Open \(file.name)")
        }
        .frame(height: 24)
    }
}
