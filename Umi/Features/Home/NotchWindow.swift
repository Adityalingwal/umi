import AppKit

final class NotchWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Umi has no Edit menu to take these keys, so the field would ignore them.
    private static let editingActions: [String: Selector] = [
        "x": #selector(NSText.cut(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "a": #selector(NSText.selectAll(_:)),
        "z": Selector(("undo:"))
    ]
    // A non-Latin layout types its own letters, so those keys are found by their place on a US layout.
    private static let usLetters: [UInt16: String] = [7: "x", 8: "c", 9: "v", 0: "a", 6: "z"]
    private static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    // Esc reaches Umi through the key listener, which stops the answer or closes the panel.
    override func cancelOperation(_ sender: Any?) {}

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(Self.shortcutModifiers) == .command,
              let action = Self.editingLetter(of: event).flatMap({ Self.editingActions[$0] }) else {
            return super.performKeyEquivalent(with: event)
        }
        return NSApp.sendAction(action, to: nil, from: self)
    }

    private static func editingLetter(of event: NSEvent) -> String? {
        guard let typed = event.charactersIgnoringModifiers?.lowercased() else { return nil }
        return typed.allSatisfy(\.isASCII) ? typed : usLetters[event.keyCode]
    }

    // The window sits over the menu bar, where AppKit would otherwise push it down.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
