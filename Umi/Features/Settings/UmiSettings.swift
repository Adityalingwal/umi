import AppKit
import Observation
import OSLog

@Observable
final class UmiSettings {
    let permissions: PermissionRows
    let brains: BrainOptions
    let version: String
    @ObservationIgnored let chatClears: AsyncStream<Void>
    @ObservationIgnored private let chatClearContinuation: AsyncStream<Void>.Continuation

    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Umi",
        category: "Settings"
    )

    init(permissions: PermissionRows, brains: BrainOptions, bundle: Bundle) {
        self.permissions = permissions
        self.brains = brains
        version = Self.version(of: bundle)
        (chatClears, chatClearContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    func pageShown(_ page: SettingsPage) {
        logger.notice("Settings shows the \(page.title, privacy: .public) page")
    }

    func clearChat() {
        logger.notice("Clear chat was confirmed in Settings")
        chatClearContinuation.yield()
    }

    func quit() {
        logger.notice("Quit Umi was clicked in Settings")
        NSApp.terminate(nil)
    }

    private static func version(of bundle: Bundle) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
