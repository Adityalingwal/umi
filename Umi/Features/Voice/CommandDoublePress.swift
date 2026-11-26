import AppKit
import Carbon.HIToolbox

struct CommandDoublePress {
    private static let longestTap: TimeInterval = 0.3
    private static let longestGap: TimeInterval = 0.4
    private static let commandKeyCodes: Set<UInt16> = [UInt16(kVK_Command), UInt16(kVK_RightCommand)]
    // Caps Lock is left out, so it never spoils a tap.
    private static let modifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]

    private var pressedAt: TimeInterval?
    private var lastTapEndedAt: TimeInterval?

    // True on the release that ends the second of two taps.
    mutating func modifiersChanged(keyCode: UInt16, flags: NSEvent.ModifierFlags, at time: TimeInterval) -> Bool {
        let held = flags.intersection(Self.modifiers)
        guard Self.commandKeyCodes.contains(keyCode) else {
            forget()
            return false
        }
        if held == .command, pressedAt == nil {
            pressedAt = time
            return false
        }
        guard !held.contains(.command), let pressedAt else {
            forget()
            return false
        }
        self.pressedAt = nil
        guard time - pressedAt <= Self.longestTap else {
            lastTapEndedAt = nil
            return false
        }
        if let lastTapEndedAt, pressedAt - lastTapEndedAt <= Self.longestGap {
            self.lastTapEndedAt = nil
            return true
        }
        lastTapEndedAt = time
        return false
    }

    // A key or a click between the presses makes Command part of a shortcut.
    mutating func otherInput() {
        forget()
    }

    private mutating func forget() {
        pressedAt = nil
        lastTapEndedAt = nil
    }
}
