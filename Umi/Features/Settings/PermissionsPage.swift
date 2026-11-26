import AppKit
import SwiftUI

struct PermissionsPage: View {
    @Environment(UmiSettings.self) private var settings

    var body: some View {
        let rows = settings.permissions
        SettingsPageLayout(page: .permissions) {
            SettingsGroup {
                PermissionRow(name: "Microphone", state: rows.microphone?.rowState, act: rows.actOnMicrophone)
                PermissionRow(name: "Screen", state: rows.screen?.rowState, act: rows.actOnScreen)
                PermissionRow(name: "Accessibility", state: rows.accessibility?.rowState, act: rows.actOnAccessibility)
            }
        }
        // The page can stay open while the user grants a permission in System Settings.
        .task {
            rows.refresh()
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                rows.refresh()
            }
        }
    }
}

private struct PermissionRowState {
    let status: String
    let action: String?
}

private struct PermissionRow: View {
    let name: String
    let state: PermissionRowState?
    let act: () -> Void

    var body: some View {
        SettingsRow(title: name, detail: state?.status ?? " ") {
            if let action = state?.action {
                RowButton(title: action, label: "\(name): \(action)", action: act)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .accessibilityValue(state?.status ?? "")
    }
}

private extension MicrophoneAccess {
    var rowState: PermissionRowState {
        switch self {
        case .notAsked: PermissionRowState(status: "Not allowed yet", action: "Allow…")
        case .allowed: PermissionRowState(status: "Allowed", action: nil)
        case .denied: PermissionRowState(status: "Denied", action: "Open System Settings")
        }
    }
}

private extension ScreenAccess {
    var rowState: PermissionRowState {
        switch self {
        case .notAsked: PermissionRowState(status: "Not allowed yet", action: "Allow…")
        case .allowed: PermissionRowState(status: "Allowed", action: nil)
        case .denied: PermissionRowState(status: "Denied", action: "Open System Settings")
        case .needsRelaunch: PermissionRowState(status: "Allowed once Umi relaunches", action: "Relaunch Umi")
        }
    }
}

private extension AccessibilityAccess {
    var rowState: PermissionRowState {
        switch self {
        case .notAsked: PermissionRowState(status: "Not allowed yet", action: "Allow…")
        case .allowed: PermissionRowState(status: "Allowed", action: nil)
        case .denied: PermissionRowState(status: "Denied", action: "Open System Settings")
        }
    }
}
