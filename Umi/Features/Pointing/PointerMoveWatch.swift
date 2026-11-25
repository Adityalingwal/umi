import AppKit

final class PointerMoveWatch {
    private static let moves: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]

    private var monitors: [Any] = []

    func start(onMove: @escaping () -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.moves) { _ in
            onMove()
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.moves) { event in
            onMove()
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }
}
