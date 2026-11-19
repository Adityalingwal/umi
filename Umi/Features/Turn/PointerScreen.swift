import AppKit

struct PointerScreen {
    let screen: NSScreen
    let displayID: CGDirectDisplayID

    static func current() -> PointerScreen? {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return PointerScreen(screen: screen, displayID: number.uint32Value)
    }
}
