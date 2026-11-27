import SwiftUI

struct FullReportButton: View {
    let show: () -> Void

    var body: some View {
        Button(action: show) {
            HStack(spacing: 3) {
                Text("Full report")
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(.white.opacity(0.12), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Open the full report")
        .accessibilityLabel("Full report")
    }
}
