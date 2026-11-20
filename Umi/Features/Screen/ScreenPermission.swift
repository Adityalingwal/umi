import AppKit
import CoreGraphics
import OSLog

enum ScreenAccess {
    case notAsked
    case allowed
    case denied
    case needsRelaunch
}

final class ScreenPermission {
    private static let requestedKey = "screenAccessRequested"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Screen")
    private let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )
    private let defaults: UserDefaults
    private let probe: ScreenAccessProbe?
    private let isGrantedAtLaunch: Bool

    private(set) var lastKnownAccess: ScreenAccess

    init(defaults: UserDefaults, probe: ScreenAccessProbe?, isGrantedAtLaunch: Bool) {
        self.defaults = defaults
        self.probe = probe
        self.isGrantedAtLaunch = isGrantedAtLaunch
        lastKnownAccess = Self.access(
            isGrantedAtLaunch: isGrantedAtLaunch,
            wasRequested: defaults.bool(forKey: Self.requestedKey),
            isGrantedNow: false
        )
    }

    static func atLaunch(defaults: UserDefaults) -> ScreenPermission {
        ScreenPermission(
            defaults: defaults,
            probe: Bundle.main.executableURL.map(ScreenAccessProbe.init),
            isGrantedAtLaunch: CGPreflightScreenCaptureAccess()
        )
    }

    func currentAccess() async -> ScreenAccess {
        let access = await checkAccess()
        lastKnownAccess = access
        return access
    }

    func requestAccess() async -> ScreenAccess {
        defaults.set(true, forKey: Self.requestedKey)
        let isGranted = CGRequestScreenCaptureAccess()
        logger.info("Screen request returned, granted: \(isGranted, privacy: .public)")
        return await currentAccess()
    }

    func openSystemSettings() {
        guard let settingsURL, NSWorkspace.shared.open(settingsURL) else {
            logger.error("Could not open the System Settings pane")
            return
        }
    }

    private static func access(isGrantedAtLaunch: Bool, wasRequested: Bool, isGrantedNow: Bool) -> ScreenAccess {
        if isGrantedAtLaunch {
            return .allowed
        }
        if isGrantedNow {
            return .needsRelaunch
        }
        return wasRequested ? .denied : .notAsked
    }

    private func checkAccess() async -> ScreenAccess {
        let wasRequested = defaults.bool(forKey: Self.requestedKey)
        guard !isGrantedAtLaunch, wasRequested else {
            return Self.access(isGrantedAtLaunch: isGrantedAtLaunch, wasRequested: wasRequested, isGrantedNow: false)
        }
        return Self.access(isGrantedAtLaunch: false, wasRequested: true, isGrantedNow: await isGrantedNow())
    }

    private func isGrantedNow() async -> Bool {
        await probe?.isGrantedNow() ?? CGPreflightScreenCaptureAccess()
    }
}
