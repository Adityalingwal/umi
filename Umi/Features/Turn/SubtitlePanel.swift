import AppKit
import SwiftUI

final class SubtitlePanel {
    private static let bottomMargin = 56.0
    private static let height = 140.0
    private static let widthFraction = 0.7

    private let panel: NSPanel

    init(subtitles: Subtitles) {
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hostingView = NSHostingView(rootView: SubtitleView().environment(subtitles))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
    }

    func show(on screen: NSScreen) {
        let area = screen.visibleFrame
        let width = area.width * Self.widthFraction
        let frame = NSRect(
            x: area.midX - width / 2,
            y: area.minY + Self.bottomMargin,
            width: width,
            height: Self.height
        )
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
    }
}
