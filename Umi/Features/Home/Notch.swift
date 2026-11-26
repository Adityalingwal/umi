import AppKit
import Observation
import OSLog

@Observable
final class Notch {
    private(set) var isOpen = false
    private(set) var isHeld = false
    var draft = "" {
        didSet { draftChanged(from: oldValue) }
    }
    @ObservationIgnored let questions: AsyncStream<String>
    @ObservationIgnored private let questionContinuation: AsyncStream<String>.Continuation
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Home")

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        (questions, questionContinuation) = AsyncStream.makeStream(of: String.self)
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

    func send() {
        let question = question
        guard !question.isEmpty else { return }
        hold()
        draft = ""
        questionContinuation.yield(question)
        logger.notice("A question was sent from the panel")
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func draftChanged(from oldValue: String) {
        guard isOpen, draft != oldValue else { return }
        hold()
    }

    private func hold() {
        guard !isHeld else { return }
        isHeld = true
        logger.notice("The user typed in the panel: it stays open until a click outside or Esc")
    }

    private func close() {
        isOpen = false
        isHeld = false
    }
}
