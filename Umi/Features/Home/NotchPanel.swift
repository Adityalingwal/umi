import AppKit
import OSLog
import SwiftUI

final class NotchPanel {
    private static let openDuration = 0.22
    private static let closeDuration = 0.16
    private static let bannerDuration = Duration.seconds(10)
    // The mark overlay sits at the status bar level; the chat stays readable above it.
    private static let aboveMarks = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    private let notch: Notch
    private let conversation: Conversation
    private let jobs: Jobs
    private let chatWindow: ChatWindowKeeper
    private let settings: UmiSettings
    private let hover = NotchHover()
    private let moves = PointerMoveWatch()
    private let clicks = ClickWatch()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")
    private var window: NotchWindow?
    private var place: NotchPlace?
    private var screenChanges: Task<Void, Never>?
    private var shortcuts: Task<Void, Never>?
    private var jobChanges: Task<Void, Never>?
    private var bannerFolding: Task<Void, Never>?
    private var isShowingWorking = false

    init(notch: Notch, conversation: Conversation, jobs: Jobs, chatWindow: ChatWindowKeeper, settings: UmiSettings) {
        self.notch = notch
        self.conversation = conversation
        self.jobs = jobs
        self.chatWindow = chatWindow
        self.settings = settings
    }

    func show(notificationCenter: NotificationCenter, commandDoublePresses: AsyncStream<Void>) {
        hover.onEnter = { [weak self] in self?.pointerEntered() }
        hover.onExit = { [weak self] in self?.pointerMayHaveLeft() }
        setUp()
        screenChanges = Task { [weak self] in
            let changes = notificationCenter.notifications(named: NSApplication.didChangeScreenParametersNotification)
            for await _ in changes {
                self?.displaysChanged()
            }
        }
        shortcuts = Task { [weak self] in
            for await _ in commandDoublePresses {
                self?.commandPressedTwice()
            }
        }
        jobChanges = Task { [weak self, jobs] in
            for await isWorking in Observations({ jobs.isWorking }) {
                self?.jobWorkingChanged(to: isWorking)
            }
        }
    }

    func stop() {
        screenChanges?.cancel()
        screenChanges = nil
        shortcuts?.cancel()
        shortcuts = nil
        jobChanges?.cancel()
        jobChanges = nil
        bannerFolding?.cancel()
        bannerFolding = nil
    }

    // The banner comes by itself and folds away after a while, or at a click elsewhere.
    func jobEnded(_ job: Job) {
        notch.jobEnded(job)
        guard notch.banner != nil else {
            logger.notice("A job ended with the panel open: its card shows it, so no banner")
            return
        }
        logger.notice("A job ended: the banner shows under the notch")
        bannerFolding?.cancel()
        bannerFolding = Task { [weak self] in
            try? await Task.sleep(for: Self.bannerDuration)
            guard !Task.isCancelled else { return }
            self?.foldBanner(because: "after ten seconds")
        }
        sizeToState()
    }

    func escape() {
        guard notch.escape() else { return }
        logger.notice("Esc: the panel closed")
        sizeToState()
    }

    // The system also sends this when only the Dock or the menu bar changes, which leaves the notch where it is.
    private func displaysChanged() {
        guard NotchPlace.onNotchedScreen(among: NSScreen.screens) != place else { return }
        logger.notice("The displays changed: the notch is set up again")
        tearDown()
        setUp()
    }

    private func setUp() {
        guard let place = NotchPlace.onNotchedScreen(among: NSScreen.screens) else {
            logger.notice("No screen has a notch, so the notch is not shown")
            return
        }
        let window = makeWindow(notchHeight: place.notchHeight)
        window.setFrame(notch.banner == nil ? place.restFrame(showing: restWord) : place.bannerFrame, display: true)
        window.orderFrontRegardless()
        self.window = window
        self.place = place
    }

    // A window kept ordered out is left behind on one Space once a full-screen Space closes, so it is not reused.
    private func tearDown() {
        notch.displaysChanged()
        moves.stop()
        clicks.stop()
        window?.orderOut(nil)
        window = nil
        place = nil
    }

    private func makeWindow(notchHeight: CGFloat) -> NotchWindow {
        let window = NotchWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Self.aboveMarks
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = hostingView(notchHeight: notchHeight)
        return window
    }

    private func hostingView(notchHeight: CGFloat) -> NSView {
        let view = NotchView(
            notchHeight: notchHeight,
            openWindow: { [weak self] in self?.openWindow() },
            toggleSettings: { [weak self] in self?.toggleSettings() },
            showReport: { [weak self] in self?.showReport() }
        )
        let hostingView = NSHostingView(
            rootView: view.environment(notch).environment(conversation).environment(jobs).environment(settings)
        )
        hostingView.sizingOptions = []
        hostingView.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: hover,
            userInfo: nil
        ))
        return hostingView
    }

    // The panel takes the keyboard without making Umi the active app.
    private func commandPressedTwice() {
        guard let window, place != nil else { return }
        let wasOpen = notch.isOpen
        notch.commandPressedTwice()
        if notch.isOpen {
            window.makeKeyAndOrderFront(nil)
            logger.notice("Command twice: the panel \(wasOpen ? "stays" : "opened", privacy: .public) for typing")
        } else {
            logger.notice("Command twice: the panel closed")
        }
        sizeToState()
    }

    private var restWord: NotchWord? {
        NotchWord.atRest(isWorking: jobs.isWorking, ended: notch.endedWord)
    }

    // At rest the notch widens for its word while a job runs; an open panel keeps its size.
    private func jobWorkingChanged(to isWorking: Bool) {
        guard isWorking != isShowingWorking else { return }
        isShowingWorking = isWorking
        logger.notice("The notch \(isWorking ? "shows Working" : "no longer shows Working", privacy: .public) at rest")
        if isWorking {
            bannerFolding?.cancel()
            notch.jobStarted()
        }
        sizeToState()
    }

    private func foldBanner(because reason: String) {
        guard notch.banner != nil else { return }
        notch.bannerFolded()
        logger.notice("The banner folded \(reason, privacy: .public)")
        if let word = restWord {
            logger.notice("The notch shows \(String(describing: word), privacy: .public) at rest")
        }
        sizeToState()
    }

    private func showReport() {
        notch.showReport()
        sizeToState()
    }

    private func openWindow() {
        notch.chatMovedToWindow()
        sizeToState()
        chatWindow.open()
    }

    private func toggleSettings() {
        notch.toggleSettingsInPanel()
        sizeToState()
    }

    // Shrinking the window under the pointer, as when the chat moves into its window, sends an enter outside the notch.
    // The window sits on whole points, so the notch's half-point edges are rounded out.
    private func pointerEntered() {
        guard !notch.isOpen, let place,
              NSMouseInRect(NSEvent.mouseLocation, place.restFrame(showing: restWord).integral, false) else {
            return
        }
        notch.pointerEntered()
        logger.notice("The pointer came to the notch: the panel opened")
        sizeToState()
    }

    // Growing the window sends an exit while the pointer is still inside it.
    private func pointerMayHaveLeft() {
        guard notch.isOpen, !notch.isHeld, let place,
              !NSMouseInRect(NSEvent.mouseLocation, place.openFrame(showing: notch.panelContent), false) else { return }
        notch.pointerLeft()
        logger.notice("The pointer left the panel: it closed")
        sizeToState()
    }

    private func clicked(at point: CGPoint) {
        guard notch.isOpen, let place,
              !NSMouseInRect(point, place.openFrame(showing: notch.panelContent), false) else { return }
        notch.clickedOutside()
        logger.notice("A click outside the panel: it closed")
        sizeToState()
    }

    // A click inside the banner is its own; only a click elsewhere folds it.
    private func clickedNearBanner(at point: CGPoint) {
        guard notch.banner != nil, let place, !NSMouseInRect(point, place.bannerFrame, false) else { return }
        foldBanner(because: "at a click elsewhere")
    }

    private func sizeToState() {
        guard let window, let place else { return }
        clicks.stop()
        moves.stop()
        if notch.isOpen {
            bannerFolding?.cancel()
            moves.start { [weak self] in self?.pointerMayHaveLeft() }
            clicks.start { [weak self] click in self?.clicked(at: click.place) }
            resize(window, to: place.openFrame(showing: notch.panelContent), duration: Self.openDuration)
        } else if notch.banner != nil {
            moves.start { [weak self] in self?.pointerEntered() }
            clicks.start { [weak self] click in self?.clickedNearBanner(at: click.place) }
            resize(window, to: place.bannerFrame, duration: Self.openDuration)
        } else {
            giveUpKey(window)
            resize(window, to: place.restFrame(showing: restWord), duration: Self.closeDuration)
        }
    }

    private func resize(_ window: NotchWindow, to frame: CGRect, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        }
    }

    // The window stays in the window list at rest, so a full-screen Space never leaves it behind.
    private func giveUpKey(_ window: NotchWindow) {
        guard window.isKeyWindow else { return }
        window.orderOut(nil)
        window.orderFrontRegardless()
    }
}
