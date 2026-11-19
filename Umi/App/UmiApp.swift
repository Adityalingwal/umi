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
    private var keyListener: KeyListener?
    private var brain: ClaudeSubscription?
    private var turns: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let listening = Listening.atLaunch(defaults: .standard)
        let accessibility = AccessibilityPermission(defaults: .standard)
        statusMenu = StatusMenu(
            appName: ProcessInfo.processInfo.processName,
            microphone: MicrophonePermission(),
            screen: .atLaunch(defaults: .standard),
            accessibility: accessibility,
            listening: listening,
            relauncher: AppRelauncher()
        )
        listening.appDidLaunch()
        let keyListener = KeyListener(accessibility: accessibility)
        keyListener.start()
        self.keyListener = keyListener
        #if DEBUG
        if let holdFile = HoldFile.atLaunch(defaults: .standard) {
            startTurns(audioSource: holdFile, holds: holdFile.holds, escapes: keyListener.escapes)
            return
        }
        #endif
        startTurns(
            audioSource: MicrophoneSource(permission: MicrophonePermission()),
            holds: keyListener.holds,
            escapes: keyListener.escapes
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusMenu?.open()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        turns?.cancel()
        keyListener?.stop()
        brain?.stop()
    }

    private func startTurns(audioSource: any AudioSource, holds: AsyncStream<HoldEvent>, escapes: AsyncStream<Void>) {
        let brain = ClaudeSubscription(
            executable: ClaudeExecutable(fileManager: .default),
            environment: ProcessInfo.processInfo.environment
        )
        brain.prepare()
        self.brain = brain
        let subtitles = Subtitles()
        let subtitlePanel = SubtitlePanel(subtitles: subtitles)
        let cursor = UmiCursor()
        let cursorPanel = CursorPanel(cursor: cursor)
        let screen = ScreenCapture.atLaunch(defaults: .standard, bundle: .main)
        let bundleURL = Bundle.main.bundleURL
        turns = Task {
            let turn = Turn(
                audioSource: audioSource,
                deepgramKey: await DeepgramKey.fromBundle(bundleURL),
                urlSession: .shared,
                screen: screen,
                brain: brain,
                subtitles: subtitles,
                subtitlePanel: subtitlePanel,
                cursor: cursor,
                cursorPanel: cursorPanel
            )
            await withDiscardingTaskGroup { group in
                group.addTask {
                    for await hold in holds {
                        await turn.handle(hold)
                    }
                }
                group.addTask {
                    for await _ in escapes {
                        await turn.clearSubtitles()
                    }
                }
            }
        }
    }
}
