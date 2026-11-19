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
    private var brain: ClaudeSubscription?
    private var holding: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let listening = Listening.atLaunch(defaults: .standard)
        statusMenu = StatusMenu(
            appName: ProcessInfo.processInfo.processName,
            microphone: MicrophonePermission(),
            screen: .atLaunch(defaults: .standard),
            accessibility: AccessibilityPermission(defaults: .standard),
            listening: listening,
            relauncher: AppRelauncher()
        )
        listening.appDidLaunch()
        #if DEBUG
        if let holdFile = HoldFile.atLaunch(defaults: .standard) {
            startTurns(audioSource: holdFile, holds: holdFile.holds)
        }
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusMenu?.open()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        holding?.cancel()
        brain?.stop()
    }

    private func startTurns(audioSource: any AudioSource, holds: AsyncStream<HoldEvent>) {
        let brain = ClaudeSubscription(
            executable: ClaudeExecutable(fileManager: .default),
            environment: ProcessInfo.processInfo.environment
        )
        brain.prepare()
        self.brain = brain
        let subtitles = Subtitles()
        let subtitlePanel = SubtitlePanel(subtitles: subtitles)
        let screen = ScreenCapture.atLaunch(defaults: .standard, bundle: .main)
        let bundleURL = Bundle.main.bundleURL
        holding = Task {
            let turn = Turn(
                audioSource: audioSource,
                deepgramKey: await DeepgramKey.fromBundle(bundleURL),
                urlSession: .shared,
                screen: screen,
                brain: brain,
                subtitles: subtitles,
                subtitlePanel: subtitlePanel
            )
            for await hold in holds {
                turn.handle(hold)
            }
        }
    }
}
