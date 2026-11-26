import SwiftUI

struct SettingsList: View {
    @Binding var page: SettingsPage
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPage.allCases) { item in
                SettingsListRow(page: item, isChosen: item == page) {
                    page = item
                }
            }
            Spacer(minLength: 0)
            Text("Version \(version)")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)
        }
        .padding(10)
    }
}

private struct SettingsListRow: View {
    let page: SettingsPage
    let isChosen: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 8) {
                PageIcon(page: page)
                Text(page.title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(isChosen ? 1 : 0.8))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(.white.opacity(isChosen ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(page.title)
        .accessibilityValue(isChosen ? "Shown" : "")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .animation(.easeOut(duration: 0.12), value: isChosen)
    }
}

private struct PageIcon: View {
    let page: SettingsPage

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(page.color, in: RoundedRectangle(cornerRadius: 5))
    }
}
