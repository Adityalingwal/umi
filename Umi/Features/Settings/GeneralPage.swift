import SwiftUI

struct GeneralPage: View {
    @Environment(UmiSettings.self) private var settings

    var body: some View {
        SettingsPageLayout(page: .general) {
            SettingsGroup {
                SettingsRow(title: "Version", detail: nil) {
                    Text(settings.version)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .textSelection(.enabled)
                }
                SettingsRow(title: "Quit Umi", detail: nil) {
                    RowButton(title: "Quit", label: "Quit Umi", action: settings.quit)
                }
            }
        }
    }
}
