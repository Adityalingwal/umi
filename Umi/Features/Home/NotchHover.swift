import AppKit

final class NotchHover: NSResponder {
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}

    override func mouseEntered(with event: NSEvent) {
        onEnter()
    }

    override func mouseExited(with event: NSEvent) {
        onExit()
    }
}
