import AppKit
import OSLog
import SwiftUI

final class NotchPanel {
    private static let openDuration = 0.22
    private static let closeDuration = 0.16
    // The mark overlay sits at the status bar level; the chat stays readable above it.
    private static let aboveMarks = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    private let notch: Notch
    private let conversation: Conversation
    private let chatWindow: ChatWindowKeeper
    private let hover = NotchHover()
    private let moves = PointerMoveWatch()
    private let clicks = ClickWatch()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")
    private var window: NotchWindow?
    private var place: NotchPlace?
    private var screenChanges: Task<Void, Never>?
    private var shortcuts: Task<Void, Never>?

    init(notch: Notch, conversation: Conversation, chatWindow: ChatWindowKeeper) {
        self.notch = notch
        self.conversation = conversation
        self.chatWindow = chatWindow
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
    }

    func stop() {
        screenChanges?.cancel()
        screenChanges = nil
        shortcuts?.cancel()
        shortcuts = nil
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
        window.setFrame(place.restFrame, display: true)
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
        let view = NotchView(notchHeight: notchHeight) { [weak self] in self?.openWindow() }
        let hostingView = NSHostingView(rootView: view.environment(notch).environment(conversation))
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

    private func openWindow() {
        notch.chatMovedToWindow()
        sizeToState()
        chatWindow.open()
    }

    // Shrinking the window under the pointer, as when the chat moves into its window, sends an enter outside the notch.
    // The window sits on whole points, so the notch's half-point edges are rounded out.
    private func pointerEntered() {
        guard !notch.isOpen, let place,
              NSMouseInRect(NSEvent.mouseLocation, place.restFrame.integral, false) else { return }
        notch.pointerEntered()
        logger.notice("The pointer came to the notch: the panel opened")
        sizeToState()
    }

    // Growing the window sends an exit while the pointer is still inside it.
    private func pointerMayHaveLeft() {
        guard notch.isOpen, !notch.isHeld, let place,
              !NSMouseInRect(NSEvent.mouseLocation, place.openFrame, false) else { return }
        notch.pointerLeft()
        logger.notice("The pointer left the panel: it closed")
        sizeToState()
    }

    private func clicked(at point: CGPoint) {
        guard notch.isOpen, let place, !NSMouseInRect(point, place.openFrame, false) else { return }
        notch.clickedOutside()
        logger.notice("A click outside the panel: it closed")
        sizeToState()
    }

    private func sizeToState() {
        guard let window, let place else { return }
        if notch.isOpen {
            moves.start { [weak self] in self?.pointerMayHaveLeft() }
            clicks.start { [weak self] click in self?.clicked(at: click.place) }
            resize(window, to: place.openFrame, duration: Self.openDuration)
        } else {
            moves.stop()
            clicks.stop()
            giveUpKey(window)
            resize(window, to: place.restFrame, duration: Self.closeDuration)
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
