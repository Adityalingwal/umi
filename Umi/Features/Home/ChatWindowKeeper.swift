import AppKit
import OSLog
import SwiftUI

final class ChatWindowKeeper: NSObject, NSWindowDelegate {
    private static let isOpenKey = "chatWindowIsOpen"
    private static let frameName = "Chat"
    private static let firstSize = CGSize(width: 720, height: 640)

    private let notch: Notch
    private let conversation: Conversation
    private let jobs: Jobs
    private let settings: UmiSettings
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")
    private var window: ChatWindow?

    init(notch: Notch, conversation: Conversation, jobs: Jobs, settings: UmiSettings, defaults: UserDefaults) {
        self.notch = notch
        self.conversation = conversation
        self.jobs = jobs
        self.settings = settings
        self.defaults = defaults
    }

    func reopenIfItWasOpen() {
        guard defaults.bool(forKey: Self.isOpenKey) else { return }
        show()
        logger.notice("The chat window was open when Umi last ran, so it opened again")
    }

    func open() {
        NSApp.activate()
        show()
        defaults.set(true, forKey: Self.isOpenKey)
        logger.notice("The chat window opened")
    }

    // Quitting Umi also closes the window, but only the user's close counts, so a quit keeps it open for next time.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        defaults.set(false, forKey: Self.isOpenKey)
        logger.notice("The user closed the chat window")
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // The closed window gives up the name, so the next one can take it.
        window?.setFrameAutosaveName("")
        window = nil
        notch.windowClosed()
        logger.notice("The chat window closed")
    }

    private func show() {
        let window = window ?? makeWindow()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        notch.windowOpened()
    }

    // A window kept ordered out is left behind on one Space once a full-screen Space closes, so each open makes one.
    private func makeWindow() -> ChatWindow {
        let window = ChatWindow(
            contentRect: CGRect(origin: .zero, size: Self.firstSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Chat"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = hostingView()
        window.delegate = self
        window.center()
        window.setFrameUsingName(Self.frameName)
        if !window.setFrameAutosaveName(Self.frameName) {
            logger.error("The chat window's size and place cannot be saved")
        }
        return window
    }

    private func hostingView() -> NSView {
        let hostingView = NSHostingView(
            rootView: ChatWindowView()
                .environment(notch)
                .environment(conversation)
                .environment(jobs)
                .environment(settings)
        )
        hostingView.sizingOptions = [.minSize]
        return hostingView
    }
}
