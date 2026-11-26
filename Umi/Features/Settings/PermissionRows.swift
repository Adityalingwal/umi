import Foundation
import Observation
import OSLog

@Observable
final class PermissionRows {
    private(set) var microphone: MicrophoneAccess?
    private(set) var screen: ScreenAccess?
    private(set) var accessibility: AccessibilityAccess?

    @ObservationIgnored private let microphonePermission: MicrophonePermission
    @ObservationIgnored private let screenPermission: ScreenPermission
    @ObservationIgnored private let accessibilityPermission: AccessibilityPermission
    @ObservationIgnored private let relauncher: AppRelauncher
    @ObservationIgnored private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Umi",
        category: "Settings"
    )
    @ObservationIgnored private var screenRefresh: Task<Void, Never>?
    @ObservationIgnored private var action: Task<Void, Never>?

    init(
        microphone: MicrophonePermission,
        screen: ScreenPermission,
        accessibility: AccessibilityPermission,
        relauncher: AppRelauncher
    ) {
        microphonePermission = microphone
        screenPermission = screen
        accessibilityPermission = accessibility
        self.relauncher = relauncher
    }

    func refresh() {
        microphone = microphonePermission.currentAccess()
        screen = screenPermission.lastKnownAccess
        refreshScreen()
        accessibility = accessibilityPermission.currentAccess()
        logRows()
    }

    func actOnMicrophone() {
        switch microphonePermission.currentAccess() {
        case .notAsked:
            logger.notice("The Microphone row asks for access")
            action = Task { [weak self] in
                guard let self else { return }
                microphone = await microphonePermission.requestAccess()
                logRows()
            }
        case .denied:
            logger.notice("The Microphone row opens System Settings")
            microphonePermission.openSystemSettings()
        case .allowed:
            break
        }
    }

    func actOnScreen() {
        switch screenPermission.lastKnownAccess {
        case .notAsked:
            logger.notice("The Screen row asks for access")
            action = Task { [weak self] in
                guard let self else { return }
                screen = await screenPermission.requestAccess()
                logRows()
            }
        case .denied:
            logger.notice("The Screen row opens System Settings")
            screenPermission.openSystemSettings()
        case .needsRelaunch:
            logger.notice("The Screen row relaunches Umi")
            action = Task { [relauncher] in
                await relauncher.relaunch()
            }
        case .allowed:
            break
        }
    }

    func actOnAccessibility() {
        switch accessibilityPermission.currentAccess() {
        case .notAsked:
            logger.notice("The Accessibility row asks for access")
            accessibility = accessibilityPermission.requestAccess()
            logRows()
        case .denied:
            logger.notice("The Accessibility row opens System Settings")
            accessibilityPermission.openSystemSettings()
        case .allowed:
            break
        }
    }

    private func refreshScreen() {
        screenRefresh?.cancel()
        screenRefresh = Task { [weak self] in
            guard let self else { return }
            let access = await screenPermission.currentAccess()
            guard !Task.isCancelled else { return }
            screen = access
            logRows()
        }
    }

    private func logRows() {
        #if DEBUG
        let rows = [
            "Microphone \(microphone.map { "\($0)" } ?? "unknown")",
            "Screen \(screen.map { "\($0)" } ?? "unknown")",
            "Accessibility \(accessibility.map { "\($0)" } ?? "unknown")"
        ]
        logger.notice("Permission rows: \(rows.joined(separator: ", "), privacy: .public)")
        #endif
    }
}
