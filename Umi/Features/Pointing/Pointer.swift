import AppKit

final class Pointer {
    private let overlay: PointerOverlay
    private let panel: PointerPanel
    private let workspace: NSWorkspace

    init(overlay: PointerOverlay, panel: PointerPanel, workspace: NSWorkspace) {
        self.overlay = overlay
        self.panel = panel
        self.workspace = workspace
    }

    func pointing(
        on displayFrame: CGRect,
        cursorRest: @escaping () -> CGPoint,
        onDepart: @escaping () -> Void
    ) -> Pointing {
        let pointing = Pointing(
            panel: panel,
            overlay: overlay,
            displayFrame: displayFrame,
            workspace: workspace,
            cursorRest: cursorRest,
            onDepart: onDepart
        )
        pointing.start(capturedApp: workspace.frontmostApplication?.processIdentifier)
        return pointing
    }
}
