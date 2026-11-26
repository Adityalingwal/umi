import AppKit
import SwiftUI

final class PointerPanel {
    static let level = NSWindow.Level.statusBar

    // The chat sits above the marks; a click or scroll there does not touch the screen under them.
    static func isAboveMarks(_ umiWindowLevel: NSWindow.Level?) -> Bool {
        umiWindowLevel.map { $0 > level } ?? false
    }

    private let content: NSView
    private var panel: NSPanel?

    init(overlay: PointerOverlay) {
        let hostingView = NSHostingView(rootView: PointerView().environment(overlay))
        hostingView.sizingOptions = []
        content = hostingView
    }

    func show(on displayFrame: CGRect) {
        let panel = panel ?? makePanel()
        panel.setFrame(displayFrame, display: false)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        // A panel kept ordered out is left on the desktop Space alone once a full-screen Space closes.
        panel = nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = Self.level
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = content
        return panel
    }
}
