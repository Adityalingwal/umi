import AppKit
import OSLog

struct AppRelauncher {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "App")

    func relaunch() async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        do {
            try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
            NSApp.terminate(nil)
        } catch {
            logger.error("Relaunch failed: \(error.localizedDescription)")
        }
    }
}
