import AppKit
import SwiftUI

final class BoardWindow {
    private static let size = NSSize(width: 760, height: 500)
    private static let smallest = NSSize(width: 420, height: 290)

    private let window: NSWindow
    private var isPlaced = false

    init(content: BoardContent) {
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentMinSize = Self.smallest
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: BoardView().environment(content))
    }

    func setTitle(_ title: String) {
        window.title = title
    }

    func show() {
        if !isPlaced {
            place()
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func place() {
        isPlaced = true
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main
        else {
            window.center()
            return
        }
        let area = screen.visibleFrame
        let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: Self.size))
        let origin = NSPoint(x: area.midX - frame.width / 2, y: area.maxY - frame.height - area.height * 0.08)
        window.setFrameOrigin(origin)
    }
}
