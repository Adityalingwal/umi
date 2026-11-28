import AppKit

final class Pointer {
    private let overlay: PointerOverlay
    private let panel: PointerPanel
    private let trail: Trail
    private let trailPanel: PointerPanel
    private let workspace: NSWorkspace

    init(overlay: PointerOverlay, panel: PointerPanel, trail: Trail, trailPanel: PointerPanel, workspace: NSWorkspace) {
        self.overlay = overlay
        self.panel = panel
        self.trail = trail
        self.trailPanel = trailPanel
        self.workspace = workspace
    }

    func trail(on displayFrame: CGRect) -> TrailDrawing {
        let drawing = TrailDrawing(
            trail: trail,
            panel: trailPanel,
            displayFrame: displayFrame,
            start: NSEvent.mouseLocation
        )
        drawing.start()
        return drawing
    }

    func pointing(
        on displayFrame: CGRect,
        cursorRest: @escaping () -> CGPoint,
        onDepart: @escaping () -> Void
    ) -> Pointing {
        let pointing = Pointing(
            stage: PointerStage(panel: panel, overlay: overlay, displayFrame: displayFrame),
            displayFrame: displayFrame,
            workspace: workspace,
            cursorRest: cursorRest,
            onDepart: onDepart
        )
        pointing.start(capturedApp: workspace.frontmostApplication?.processIdentifier)
        return pointing
    }
}
