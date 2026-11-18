import AppKit
import AVFoundation
import OSLog

enum MicrophoneAccess {
    case notAsked
    case allowed
    case denied
}

struct MicrophonePermission {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")

    func currentAccess() -> MicrophoneAccess {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            .notAsked
        case .authorized:
            .allowed
        case .denied, .restricted:
            .denied
        @unknown default:
            .denied
        }
    }

    func requestAccess() async -> MicrophoneAccess {
        let isGranted = await AVCaptureDevice.requestAccess(for: .audio)
        logger.info("Microphone request finished, granted: \(isGranted, privacy: .public)")
        return currentAccess()
    }

    func openSystemSettings() {
        guard let settingsURL else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}
