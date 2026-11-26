import AppKit
import Observation
import OSLog

@Observable
final class Notch {
    private static let readAloudKey = "readAloud"

    private(set) var isOpen = false
    private(set) var isHeld = false
    private(set) var isFieldWanted = false
    private(set) var isWindowFieldWanted = false
    private(set) var readsAloud: Bool
    var draft = "" {
        didSet { draftChanged(from: oldValue) }
    }
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
        isFieldWanted = true
    }

    func fieldTookFocus() {
        isFieldWanted = false
    }

    func windowOpened() {
        isWindowFieldWanted = true
    }

    func windowFieldTookFocus() {
        isWindowFieldWanted = false
    }

    // A click in the panel makes it key, so its field takes the keys typed next.
    func toggleReadAloud() {
        readsAloud.toggle()
        isFieldWanted = isOpen
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

    func send() {
        let question = question
        guard !question.isEmpty else { return }
        hold()
        draft = ""
        questionContinuation.yield(SentQuestion(text: question, readsAloud: readsAloud))
        logger.notice("A typed question was sent")
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func draftChanged(from oldValue: String) {
        guard isOpen, draft != oldValue else { return }
        hold()
    }

    // Only the panel is held; typing or sending in the window leaves it as it is.
    private func hold() {
        guard isOpen, !isHeld else { return }
        isHeld = true
        logger.notice("The user typed in the panel: it stays open until a click outside or Esc")
    }

    private func close() {
        isOpen = false
        isHeld = false
        isFieldWanted = false
    }
}
