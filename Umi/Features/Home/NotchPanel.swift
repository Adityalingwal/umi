import AppKit
import OSLog
import SwiftUI

final class NotchPanel {
    private static let openDuration = 0.22
    private static let closeDuration = 0.16
    // The pointer overlay and the cursor sit at the status bar level; the chat stays readable above them.
    private static let aboveMarks = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    private let notch: Notch
    private let conversation: Conversation
    private let window: NotchWindow
    private let hover = NotchHover()
    private let moves = PointerMoveWatch()
    private let clicks = ClickWatch()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")
    private var place: NotchPlace?
    private var screenChanges: Task<Void, Never>?
    private var hasContent = false

    init(notch: Notch, conversation: Conversation) {
        self.notch = notch
        self.conversation = conversation
        window = NotchWindow(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = Self.aboveMarks
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    func show(notificationCenter: NotificationCenter) {
        hover.onEnter = { [weak self] in self?.pointerEntered() }
        hover.onExit = { [weak self] in self?.pointerMayHaveLeft() }
        placeOnNotchedScreen()
        screenChanges = Task { [weak self] in
            let changes = notificationCenter.notifications(named: NSApplication.didChangeScreenParametersNotification)
            for await _ in changes {
                self?.placeOnNotchedScreen()
            }
        }
    }

    func stop() {
        screenChanges?.cancel()
        screenChanges = nil
    }

    func escape() {
        guard notch.escape() else { return }
        logger.notice("Esc: the panel closed")
        sizeToState()
    }

    private func placeOnNotchedScreen() {
        guard let place = NotchPlace.onNotchedScreen(among: NSScreen.screens) else {
            logger.notice("No screen has a notch, so the notch is not shown")
            self.place = nil
            window.orderOut(nil)
            return
        }
        self.place = place
        if !hasContent {
            window.contentView = hostingView(notchHeight: place.notchHeight)
            hasContent = true
        }
        window.setFrame(notch.isOpen ? place.openFrame : place.restFrame, display: true)
        window.orderFrontRegardless()
    }

    private func hostingView(notchHeight: CGFloat) -> NSView {
        let hostingView = NSHostingView(
            rootView: NotchView(notchHeight: notchHeight).environment(notch).environment(conversation)
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

    private func pointerEntered() {
        guard !notch.isOpen else { return }
        notch.pointerEntered()
        logger.notice("The pointer came to the notch: the panel opened")
        sizeToState()
    }

    // Growing the window sends an exit while the pointer is still inside it.
    private func pointerMayHaveLeft() {
        guard notch.isOpen, let place, !NSMouseInRect(NSEvent.mouseLocation, place.openFrame, false) else { return }
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
        guard let place else { return }
        if notch.isOpen {
            moves.start { [weak self] in self?.pointerMayHaveLeft() }
            clicks.start { [weak self] click in self?.clicked(at: click.place) }
            resize(to: place.openFrame, duration: Self.openDuration)
        } else {
            moves.stop()
            clicks.stop()
            giveUpKey()
            resize(to: place.restFrame, duration: Self.closeDuration)
        }
    }

    private func resize(to frame: CGRect, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        }
    }

    // The window stays in the window list at rest, so a full-screen Space never leaves it behind.
    private func giveUpKey() {
        guard window.isKeyWindow else { return }
        window.orderOut(nil)
        window.orderFrontRegardless()
    }
}
