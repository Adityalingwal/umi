import AppKit

final class ClickWatch {
    private static let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

    private var monitors: [Any] = []

    var isWatching: Bool {
        !monitors.isEmpty
    }

    func start(onClick: @escaping () -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.clicks) { _ in
            onClick()
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.clicks) { event in
            onClick()
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }
}
