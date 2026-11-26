import AppKit
import Observation

@Observable
final class Notch {
    private(set) var isOpen = false
    @ObservationIgnored private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
    }

    func pointerEntered() {
        isOpen = true
    }

    func pointerLeft() {
        isOpen = false
    }

    func clickedOutside() {
        isOpen = false
    }

    func escape() -> Bool {
        guard isOpen else { return false }
        isOpen = false
        return true
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
