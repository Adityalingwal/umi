import AppKit
import Observation
import OSLog

@Observable
final class Notch {
    private static let readAloudKey = "readAloud"

    private(set) var isOpen = false
    private(set) var isHeld = false
    private(set) var readsAloud: Bool
    private(set) var panelContent = HomeContent.chat
    private(set) var windowContent = HomeContent.chat
    var draft = ""
    private var isPanelFieldWanted = false
    private var isWindowFieldWanted = false
    @ObservationIgnored let questions: AsyncStream<SentQuestion>
    @ObservationIgnored private let questionContinuation: AsyncStream<SentQuestion>.Continuation
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")

    init(pasteboard: NSPasteboard, defaults: UserDefaults) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        readsAloud = defaults.object(forKey: Self.readAloudKey) as? Bool ?? true
        (questions, questionContinuation) = AsyncStream.makeStream(of: SentQuestion.self)
    }

    var canSend: Bool {
        !question.isEmpty
    }

    func isFieldWanted(in place: AskPlace) -> Bool {
        switch place {
        case .panel: isPanelFieldWanted
        case .window: isWindowFieldWanted
        }
    }

    private var question: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func pointerEntered() {
        isOpen = true
    }

    // Held at once, so the panel stays while the pointer is elsewhere.
    func commandPressedTwice() {
        guard !(isOpen && isHeld) else {
            close()
            return
        }
        isOpen = true
        isHeld = true
        panelContent = .chat
        isPanelFieldWanted = true
    }

    func fieldTookFocus(in place: AskPlace) {
        switch place {
        case .panel: isPanelFieldWanted = false
        case .window: isWindowFieldWanted = false
        }
    }

    func windowOpened() {
        isWindowFieldWanted = windowContent == .chat
    }

    func windowClosed() {
        windowContent = .chat
    }

    // One button in one place opens and leaves Settings, so it stays under the pointer as the panel changes width.
    func toggleSettingsInPanel() {
        panelContent = panelContent == .chat ? .settings : .chat
        logger.notice("The panel shows \(self.panelContent == .chat ? "the chat" : "Settings", privacy: .public)")
    }

    func showSettingsInWindow() {
        windowContent = .settings
        logger.notice("The chat window shows Settings")
    }

    func showChatInWindow() {
        windowContent = .chat
        isWindowFieldWanted = true
        logger.notice("The chat window is back to the chat")
    }

    // A click on the switch readies the field beside it for the keys typed next.
    func toggleReadAloud(in place: AskPlace) {
        readsAloud.toggle()
        switch place {
        case .panel: isPanelFieldWanted = isOpen
        case .window: isWindowFieldWanted = true
        }
        defaults.set(readsAloud, forKey: Self.readAloudKey)
        logger.notice("Read aloud is now \(self.readsAloud ? "on" : "off", privacy: .public)")
    }

    func pointerLeft() {
        close()
    }

    func clickedOutside() {
        close()
    }

    func displaysChanged() {
        close()
    }

    func escape() -> Bool {
        guard isOpen else { return false }
        close()
        return true
    }

    // The chat moves into the window, so the panel closes.
    func chatMovedToWindow() {
        close()
        logger.notice("The panel's window button was clicked")
    }

    // Only the panel's own field holds the panel; the text itself is shared with the window.
    func fieldEdited(in place: AskPlace) {
        guard place == .panel else { return }
        hold()
    }

    func send(from place: AskPlace) {
        let question = question
        guard !question.isEmpty else { return }
        if place == .panel {
            hold()
        }
        draft = ""
        questionContinuation.yield(SentQuestion(text: question, readsAloud: readsAloud))
        logger.notice("A typed question was sent")
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func hold() {
        guard isOpen, !isHeld else { return }
        isHeld = true
        logger.notice("The user typed in the panel: it stays open until a click outside or Esc")
    }

    private func close() {
        isOpen = false
        isHeld = false
        isPanelFieldWanted = false
        panelContent = .chat
    }
}
