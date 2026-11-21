import AppKit
import SwiftUI

final class PointerPanel {
    private let panel: NSPanel

    init(overlay: PointerOverlay) {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: PointerView().environment(overlay))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func show(on displayFrame: CGRect) {
        panel.setFrame(displayFrame, display: false)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
