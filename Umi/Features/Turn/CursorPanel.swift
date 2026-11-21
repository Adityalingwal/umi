import AppKit
import SwiftUI

final class CursorPanel {
    private static let size = NSSize(width: 48, height: 28)
    private static let gapBelowPointer = 22.0
    private static let pointerEvents: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]

    private let panel: NSPanel
    private var monitors: [Any] = []

    init(cursor: UmiCursor) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: CursorView().environment(cursor))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    var center: CGPoint {
        CGPoint(x: panel.frame.midX, y: panel.frame.midY)
    }

    func startFollowingPointer() {
        moveToPointer()
        panel.orderFrontRegardless()
        guard monitors.isEmpty else { return }
        let otherApps = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerEvents) { [weak self] _ in
            self?.moveToPointer()
        }
        let umi = NSEvent.addLocalMonitorForEvents(matching: Self.pointerEvents) { [weak self] event in
            self?.moveToPointer()
            return event
        }
        monitors = [otherApps, umi].compactMap(\.self)
    }

    func stopFollowingPointer() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func moveToPointer() {
        let pointer = NSEvent.mouseLocation
        var origin = NSPoint(
            x: pointer.x - Self.size.width / 2,
            y: pointer.y - Self.gapBelowPointer - Self.size.height
        )
        if let area = PointerScreen.current()?.screen.frame {
            if origin.y < area.minY {
                origin.y = pointer.y + Self.gapBelowPointer / 2
            }
            origin.x = min(max(origin.x, area.minX), area.maxX - Self.size.width)
        }
        panel.setFrameOrigin(origin)
    }
}
