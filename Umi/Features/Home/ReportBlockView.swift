import SwiftUI

struct ReportBlockView: View {
    private static let indent = 16.0

    let block: JobReport.Block

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(text)
                .font(.system(size: Self.headingSize(level), weight: level <= 2 ? .bold : .semibold))
                .foregroundStyle(.white)
                .padding(.top, level <= 2 ? 8 : 4)
        case .paragraph(let text):
            ReportText(text: text)
        case let .listItem(marker, depth, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(marker)
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(minWidth: 12, alignment: .trailing)
                ReportText(text: text)
            }
            .padding(.leading, Double(max(depth - 1, 0)) * Self.indent)
        case .quote(let text):
            ReportText(text: text)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.25))
                        .frame(width: 2)
                }
        case .plain(let text):
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        case .rule:
            Divider()
                .overlay(.white.opacity(0.2))
        }
    }

    private static func headingSize(_ level: Int) -> Double {
        switch level {
        case 1: 20
        case 2: 16
        default: 14
        }
    }
}

private struct ReportText: View {
    let text: AttributedString

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.85))
            .tint(Color(red: 0.45, green: 0.72, blue: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}
