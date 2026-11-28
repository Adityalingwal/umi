import AppKit
import OSLog

final class TrailDrawing {
    private let trail: Trail
    private let panel: PointerPanel
    private let displayFrame: CGRect
    private let moves = PointerMoveWatch()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var path: PointerPath?
    private var isShown = false
    private var hiding: Task<Void, Never>?

    init(trail: Trail, panel: PointerPanel, displayFrame: CGRect, start: CGPoint) {
        self.trail = trail
        self.panel = panel
        self.displayFrame = displayFrame
        path = PointerPath(displayFrame: displayFrame, start: start)
    }

    func start() {
        trail.clear()
        moves.start { [weak self] in
            self?.pointerMoved()
        }
    }

    // The path is dropped here; only the painted parts stay, for the release fade.
    func end() -> Bool {
        moves.stop()
        let hasMark = path?.hasMark ?? false
        path = nil
        fadeOut()
        return hasMark
    }

    func stop() {
        moves.stop()
        path = nil
        hiding?.cancel()
        hiding = nil
        if isShown {
            logger.notice("The trail is gone at once")
        }
        hide()
    }

    private func pointerMoved() {
        guard var path else { return }
        let hadMark = path.hasMark
        let step = path.add(NSEvent.mouseLocation)
        self.path = path
        guard let step else { return }
        if !hadMark {
            logger.notice("The pointer left the start circle, so the trail is painted")
        }
        if !isShown {
            showPanel()
        }
        trail.paint(TrailPart(start: viewPoint(step.start), end: viewPoint(step.end), paintedAt: .now))
    }

    private func showPanel() {
        panel.show(on: displayFrame)
        isShown = true
        let asked = displayFrame.debugDescription
        let placement = panel.placement
        logger.notice("The trail's panel shows: asked \(asked, privacy: .private), \(placement, privacy: .private)")
    }

    private func fadeOut() {
        guard isShown else { return }
        trail.release(at: .now)
        hiding = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Trail.releaseFade))
            guard !Task.isCancelled, let self else { return }
            hide()
            logger.notice("The trail faded out")
        }
    }

    private func hide() {
        isShown = false
        trail.clear()
        panel.hide()
    }

    private func viewPoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - displayFrame.minX, y: displayFrame.maxY - screenPoint.y)
    }
}
