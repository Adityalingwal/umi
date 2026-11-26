import AppKit

final class ScrollWatch {
    private var monitors: [Any] = []

    // Tells whether the scroll landed in one of Umi's own windows.
    func start(onScroll: @escaping (_ isInUmiWindow: Bool) -> Void) {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
            if Self.movesContent(event) {
                onScroll(false)
            }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if Self.movesContent(event) {
                onScroll(event.window != nil)
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
