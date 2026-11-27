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
    private var keyListener: KeyListener?
    private var brain: ChosenBrain?
    private var notchPanel: NotchPanel?
    private var chatWindow: ChatWindowKeeper?
    private var conversation: Conversation?
    private var jobs: Jobs?
    private var turns: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isTestHost(ProcessInfo.processInfo.environment) else { return }
        let accessibility = AccessibilityPermission(defaults: .standard)
        let keyListener = KeyListener(accessibility: accessibility)
        let parts = BrainParts(environment: ProcessInfo.processInfo.environment, defaults: .standard)
        let brain = parts.makeChosenBrain(defaults: .standard)
        brain.prepare()
        self.brain = brain
        let settings = Self.makeSettings(brain: brain, check: parts.makeCheck(), accessibility: accessibility)
        keyListener.start()
        self.keyListener = keyListener
        let conversation = Conversation(file: ChatFile(folder: Self.chatFolder(defaults: .standard)))
        self.conversation = conversation
        let jobs = parts.makeJobs(folder: Self.umiFolder.appending(path: "Jobs"))
        self.jobs = jobs
        let notch = Notch(pasteboard: .general, defaults: .standard)
        let presses = keyListener.commandDoublePresses
        showHome(notch: notch, conversation: conversation, settings: settings, commandDoublePresses: presses)
        #if DEBUG
        if let holdFile = HoldFile.atLaunch(defaults: .standard) {
            let picks = BrainPicks.atLaunch(defaults: .standard, brain: brain)
            let holds = picks?.applied(to: holdFile.holds) ?? holdFile.holds
            startTurns(
                questions: QuestionSources(audio: holdFile, holds: holds, typed: notch.questions),
                escapes: keyListener.escapes,
                chatClears: settings.chatClears,
                brain: BrainWithJobs(brain: brain, jobs: jobs),
                conversation: conversation
            )
            return
        }
        #endif
        startTurns(
            questions: QuestionSources(
                audio: MicrophoneSource(permission: MicrophonePermission()),
                holds: keyListener.holds,
                typed: notch.questions
            ),
            escapes: keyListener.escapes,
            chatClears: settings.chatClears,
            brain: BrainWithJobs(brain: brain, jobs: jobs),
            conversation: conversation
        )
    }

    private static func chatFolder(defaults: UserDefaults) -> URL {
        #if DEBUG
        if let folder = defaults.string(forKey: "UmiChatFolder") {
            return URL(filePath: folder)
        }
        #endif
        return umiFolder
    }

    private static var umiFolder: URL {
        URL.applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "Umi")
    }

    private static func makeSettings(
        brain: ChosenBrain,
        check: BrainCheck,
        accessibility: AccessibilityPermission
    ) -> UmiSettings {
        UmiSettings(
            permissions: PermissionRows(
                microphone: MicrophonePermission(),
                screen: .atLaunch(defaults: .standard),
                accessibility: accessibility,
                relauncher: AppRelauncher()
            ),
            brains: BrainOptions(brain: brain, check: check),
            bundle: .main
        )
    }

    private func showHome(
        notch: Notch,
        conversation: Conversation,
        settings: UmiSettings,
        commandDoublePresses: AsyncStream<Void>
    ) {
        let chatWindow = ChatWindowKeeper(
            notch: notch,
            conversation: conversation,
            settings: settings,
            defaults: .standard
        )
        let notchPanel = NotchPanel(
            notch: notch,
            conversation: conversation,
            chatWindow: chatWindow,
            settings: settings
        )
        notchPanel.show(notificationCenter: .default, commandDoublePresses: commandDoublePresses)
        chatWindow.reopenIfItWasOpen()
        self.notchPanel = notchPanel
        self.chatWindow = chatWindow
    }

    // The shared scheme's Test action sets this variable in the app that hosts the tests.
    private static func isTestHost(_ environment: [String: String]) -> Bool {
        environment["UMI_TEST_HOST"] == "1"
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        chatWindow?.open()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let conversation else { return .terminateNow }
        Task {
            await conversation.saveAnswerBeforeQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        turns?.cancel()
        jobs?.stopAtQuit()
        keyListener?.stop()
        notchPanel?.stop()
        brain?.stop()
    }

    private func startTurns(
        questions: QuestionSources,
        escapes: AsyncStream<Void>,
        chatClears: AsyncStream<Void>,
        brain: BrainWithJobs,
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
            await conversation.load()
            let turn = Turn(
                audioSource: questions.audio,
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
                    for await hold in questions.holds {
                        await turn.handle(hold)
                    }
                }
                group.addTask {
                    for await question in questions.typed {
                        await turn.ask(typed: question.text, readsAloud: question.readsAloud)
                    }
                }
                group.addTask {
                    for await _ in escapes {
                        await Self.escape(turn: turn, notchPanel: notchPanel)
                    }
                }
                group.addTask {
                    for await _ in chatClears {
                        await Self.clearChat(turn: turn, board: board, conversation: conversation)
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

    // A running answer stops exactly as Esc stops it, and first, so nothing it writes later finds its question.
    private static func clearChat(turn: Turn, board: Board, conversation: Conversation) {
        turn.escape()
        board.forget()
        conversation.clear()
    }
}
