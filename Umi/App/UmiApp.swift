import AppKit

@main
enum UmiApp {
    static func main() {
        ScreenAccessProbe.exitIfRequested(arguments: CommandLine.arguments)
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusMenu: StatusMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenu = StatusMenu(
            appName: ProcessInfo.processInfo.processName,
            microphone: MicrophonePermission(),
            screen: .atLaunch(defaults: .standard),
            relauncher: AppRelauncher()
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusMenu?.open()
        return false
    }
}
