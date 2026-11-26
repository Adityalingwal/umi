import AppKit
import Carbon.HIToolbox
import IOKit.hidsystem

struct RightOptionHold {
    private enum Phase {
        case released
        case asking
        case waitingForRelease
    }

    static let keyCode = UInt16(kVK_RightOption)
    private static let rightOptionBit = UInt(NX_DEVICERALTKEYMASK)
    private static let leftOptionBit = UInt(NX_DEVICELALTKEYMASK)
    private static let otherModifiers: NSEvent.ModifierFlags = [.command, .control, .shift, .function]

    private var phase = Phase.released

    var isKeyDown: Bool {
        phase != .released
    }

    mutating func modifiersChanged(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> HoldEvent? {
        guard keyCode == Self.keyCode else {
            return keyPressed()
        }
        let isDown = flags.rawValue & Self.rightOptionBit != 0
        switch (phase, isDown) {
        case (.released, true):
            guard !Self.isOtherModifierHeld(in: flags) else {
                phase = .waitingForRelease
                return nil
            }
            phase = .asking
            return .began
        case (.asking, false):
            phase = .released
            return .ended
        case (.waitingForRelease, false):
            phase = .released
            return nil
        case (.asking, true), (.waitingForRelease, true), (.released, false):
            return nil
        }
    }

    mutating func keyPressed() -> HoldEvent? {
        guard phase == .asking else { return nil }
        phase = .waitingForRelease
        return .cancelled
    }

    private static func isOtherModifierHeld(in flags: NSEvent.ModifierFlags) -> Bool {
        !flags.isDisjoint(with: otherModifiers) || flags.rawValue & leftOptionBit != 0
    }
}
