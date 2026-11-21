import AppKit

final class AppSwitchWatch {
    private let workspace: NSWorkspace
    private var observation: NotificationCenter.ObservationToken?

    init(workspace: NSWorkspace) {
        self.workspace = workspace
    }

    func start(capturedApp: pid_t?, onSwitch: @escaping () -> Void) {
        guard observation == nil else { return }
        observation = workspace.notificationCenter.addObserver(of: workspace, for: .didActivateApplication) { message in
            guard message.application.processIdentifier != capturedApp else { return }
            onSwitch()
        }
    }

    func stop() {
        observation.map(workspace.notificationCenter.removeObserver)
        observation = nil
    }
}
