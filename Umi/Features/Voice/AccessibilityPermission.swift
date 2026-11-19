import AppKit
import ApplicationServices
import OSLog

enum AccessibilityAccess {
    case notAsked
    case allowed
    case denied
}

struct AccessibilityPermission {
    private static let requestedKey = "accessibilityAccessRequested"
    // The value of kAXTrustedCheckOptionPrompt, a C global var that Swift 6 does not allow reading.
    private static let promptOption = "AXTrustedCheckOptionPrompt"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func currentAccess() -> AccessibilityAccess {
        if AXIsProcessTrusted() {
            return .allowed
        }
        return defaults.bool(forKey: Self.requestedKey) ? .denied : .notAsked
    }

    func requestAccess() -> AccessibilityAccess {
        defaults.set(true, forKey: Self.requestedKey)
        let options = [Self.promptOption: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility request returned, trusted: \(isTrusted, privacy: .public)")
        return currentAccess()
    }

    func openSystemSettings() {
        guard let settingsURL, NSWorkspace.shared.open(settingsURL) else {
            logger.error("Could not open the System Settings pane")
            return
        }
    }
}
