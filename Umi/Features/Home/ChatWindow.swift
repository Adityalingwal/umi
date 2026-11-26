import AppKit

final class ChatWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let action = EditingKeys.action(for: event) else {
            return super.performKeyEquivalent(with: event)
        }
        return NSApp.sendAction(action, to: nil, from: self)
    }
}
