import SwiftUI

struct SettingsView: View {
    private static let listWidth = 150.0

    @Environment(UmiSettings.self) private var settings
    @State private var page = SettingsPage.permissions

    var body: some View {
        HStack(spacing: 0) {
            SettingsList(page: $page, version: settings.version)
                .frame(width: Self.listWidth)
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
            SettingsPageContent(page: page)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: page, initial: true) {
            settings.pageShown(page)
        }
    }
}

private struct SettingsPageContent: View {
    let page: SettingsPage

    var body: some View {
        switch page {
        case .permissions: PermissionsPage()
        case .brain: BrainPage()
        case .general: GeneralPage()
        }
    }
}
