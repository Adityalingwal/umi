import SwiftUI

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Group(subviews: content) { rows in
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.leading, 12)
                    }
                    row
                }
            }
        }
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
