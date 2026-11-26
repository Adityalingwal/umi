import AppKit

final class ChatWindow: NSWindow {
    // Umi has no main menu, so the window takes the standard window keys itself.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        switch EditingKeys.commandLetter(of: event) {
        case "w":
            performClose(nil)
            return true
        case "m":
            performMiniaturize(nil)
            return true
        case "q":
            NSApp.terminate(nil)
            return true
        default:
            guard let action = EditingKeys.action(for: event) else {
                return super.performKeyEquivalent(with: event)
            }
            return NSApp.sendAction(action, to: nil, from: self)
        }
    }
}
