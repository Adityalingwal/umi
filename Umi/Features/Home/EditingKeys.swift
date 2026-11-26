import AppKit

// Umi has no Edit menu to take these keys, so a text field in its windows would ignore them.
enum EditingKeys {
    private static let actions: [String: Selector] = [
        "x": #selector(NSText.cut(_:)),
        "c": #selector(NSText.copy(_:)),
        "v": #selector(NSText.paste(_:)),
        "a": #selector(NSText.selectAll(_:)),
        "z": Selector(("undo:"))
    ]
    // A non-Latin layout types its own letters, so those keys are found by their place on a US layout.
    private static let usLetters: [UInt16: String] = [
        7: "x", 8: "c", 9: "v", 0: "a", 6: "z", 13: "w", 46: "m", 12: "q"
    ]
    private static let shortcutModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    static func action(for event: NSEvent) -> Selector? {
        commandLetter(of: event).flatMap { actions[$0] }
    }

    // The letter typed with Command alone, or nil for any other key or modifier.
    static func commandLetter(of event: NSEvent) -> String? {
        guard event.modifierFlags.intersection(shortcutModifiers) == .command else { return nil }
        let typed = event.characters?.lowercased() ?? ""
        return !typed.isEmpty && typed.allSatisfy(\.isASCII) ? typed : usLetters[event.keyCode]
    }
}
