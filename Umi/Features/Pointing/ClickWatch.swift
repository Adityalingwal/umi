import AppKit

final class ClickWatch {
    private static let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

    private var monitors: [Any] = []

    var isWatching: Bool {
        !monitors.isEmpty
    }

    func start(onClick: @escaping (CGPoint) -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.clicks) { event in
            onClick(Self.screenPlace(of: event))
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.clicks) { event in
            onClick(Self.screenPlace(of: event))
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private static func screenPlace(of event: NSEvent) -> CGPoint {
        guard let window = event.window else { return event.locationInWindow }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
