import AppKit

final class ClickWatch {
    struct Click {
        let place: CGPoint
        let umiWindowLevel: NSWindow.Level?
    }

    private static let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

    private var monitors: [Any] = []

    var isWatching: Bool {
        !monitors.isEmpty
    }

    func start(onClick: @escaping (Click) -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.clicks) { event in
            Self.pass(event, to: onClick)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.clicks) { event in
            Self.pass(event, to: onClick)
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    // A double-click's later presses land where its first press did, on a mark the first press already cleared.
    private static func pass(_ event: NSEvent, to onClick: (Click) -> Void) {
        guard event.clickCount <= 1 else { return }
        onClick(Click(place: screenPlace(of: event), umiWindowLevel: event.window?.level))
    }

    private static func screenPlace(of event: NSEvent) -> CGPoint {
        guard let window = event.window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
