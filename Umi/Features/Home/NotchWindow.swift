import AppKit

final class NotchWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Esc reaches Umi through the key listener, which stops the answer or closes the panel.
    override func cancelOperation(_ sender: Any?) {}

    // The window sits over the menu bar, where AppKit would otherwise push it down.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
