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
    private var brain: ChosenBrain?
    private var notchPanel: NotchPanel?
    private var turns: Task<Void, Never>?
    #if DEBUG
    private var menuUpdates: Task<Void, Never>?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isTestHost(ProcessInfo.processInfo.environment) else { return }
        let listening = Listening.atLaunch(defaults: .standard)
        let accessibility = AccessibilityPermission(defaults: .standard)
        let keyListener = KeyListener(accessibility: accessibility)
        let parts = BrainParts(environment: ProcessInfo.processInfo.environment, defaults: .standard)
        let brain = parts.makeChosenBrain(defaults: .standard)
        brain.prepare()
        self.brain = brain
        statusMenu = StatusMenu(
            appName: ProcessInfo.processInfo.processName,
            microphone: MicrophonePermission(),
            screen: .atLaunch(defaults: .standard),
            accessibility: accessibility,
            keyListener: keyListener,
            listening: listening,
            brainRow: BrainRow(brain: brain, check: parts.makeCheck()),
            relauncher: AppRelauncher()
        )
        listening.appDidLaunch()
        keyListener.start()
        self.keyListener = keyListener
        let conversation = Conversation()
        let notchPanel = NotchPanel(notch: Notch(pasteboard: .general), conversation: conversation)
        notchPanel.show(on: NSScreen.screens)
        self.notchPanel = notchPanel
        #if DEBUG
        menuUpdates = statusMenu.flatMap { MenuUpdates.start(defaults: .standard, menu: $0) }
        if let holdFile = HoldFile.atLaunch(defaults: .standard) {
            let picks = BrainPicks.atLaunch(defaults: .standard, brain: brain)
            let holds = picks?.applied(to: holdFile.holds) ?? holdFile.holds
            startTurns(
                audioSource: holdFile,
                holds: holds,
                escapes: keyListener.escapes,
                brain: brain,
                conversation: conversation
            )
            return
        }
        #endif
        startTurns(
            audioSource: MicrophoneSource(permission: MicrophonePermission()),
            holds: keyListener.holds,
            escapes: keyListener.escapes,
            brain: brain,
            conversation: conversation
        )
    }

    // The shared scheme's Test action sets this variable in the app that hosts the tests.
    private static func isTestHost(_ environment: [String: String]) -> Bool {
        environment["UMI_TEST_HOST"] == "1"
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusMenu?.open()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        turns?.cancel()
        #if DEBUG
        menuUpdates?.cancel()
        #endif
        keyListener?.stop()
        brain?.stop()
    }

    private func startTurns(
        audioSource: any AudioSource,
        holds: AsyncStream<HoldEvent>,
        escapes: AsyncStream<Void>,
        brain: ChosenBrain,
        conversation: Conversation
    ) {
        let cursor = UmiCursor()
        let cursorPanel = CursorPanel(cursor: cursor)
        let pointerOverlay = PointerOverlay()
        let pointer = Pointer(overlay: pointerOverlay, panel: PointerPanel(overlay: pointerOverlay), workspace: .shared)
        let screen = ScreenCapture.atLaunch(defaults: .standard, bundle: .main)
        let boardContent = BoardContent()
        let board = Board(content: boardContent, window: BoardWindow(content: boardContent))
        let bundleURL = Bundle.main.bundleURL
        let notchPanel = notchPanel
        turns = Task {
            let turn = Turn(
                audioSource: audioSource,
                speech: await SpeechToText.atLaunch(bundleURL: bundleURL, defaults: .standard, session: .shared),
                speaker: await Speaker.atLaunch(bundleURL: bundleURL, defaults: .standard, session: .shared),
                screen: screen,
                brain: brain,
                conversation: conversation,
                cursor: cursor,
                cursorPanel: cursorPanel,
                pointer: pointer,
                board: board
            )
            await withDiscardingTaskGroup { group in
                group.addTask {
                    for await hold in holds {
                        await turn.handle(hold)
                    }
                }
                group.addTask {
                    for await _ in escapes {
                        await Self.escape(turn: turn, notchPanel: notchPanel)
                    }
                }
            }
        }
    }

    private static func escape(turn: Turn, notchPanel: NotchPanel?) {
        let wasAnswering = turn.isAnswering
        turn.escape()
        guard !wasAnswering else { return }
        notchPanel?.escape()
    }
}
