import AppKit

final class ScrollWatch {
    private var monitors: [Any] = []

    func start(onScroll: @escaping () -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
            if Self.movesContent(event) {
                onScroll()
            }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if Self.movesContent(event) {
                onScroll()
            }
            return event
        }
        monitors = [global, local].compactMap(\.self)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    // A finger resting on the trackpad, or a gesture ending, sends scroll events that move nothing.
    private static func movesContent(_ event: NSEvent) -> Bool {
        event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0
    }
}
