import SwiftUI

struct SettingsPageLayout<Content: View>: View {
    let page: SettingsPage
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(page.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(page.line)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 3)
                VStack(spacing: 14) {
                    content
                }
                .padding(.top, 16)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }
}
