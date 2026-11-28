import AppKit
import OSLog

final class TrailDrawing {
    private let trail: Trail
    private let panel: PointerPanel
    private let moves = PointerMoveWatch()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var path: PointerPath
    private var isShown = false
    private var hiding: Task<Void, Never>?

    init(trail: Trail, panel: PointerPanel, displayFrame: CGRect, start: CGPoint) {
        self.trail = trail
        self.panel = panel
        path = PointerPath(displayFrame: displayFrame, start: start)
    }

    func start() {
        trail.clear()
        moves.start { [weak self] in
            self?.pointerMoved()
        }
    }

    func end() -> PointerPath {
        moves.stop()
        let ended = path
        path = PointerPath(displayFrame: path.displayFrame, start: path.start)
        fadeOut()
        return ended
    }

    func stop() {
        moves.stop()
        hiding?.cancel()
        hiding = nil
        if isShown {
            logger.notice("The trail is gone at once")
        }
        hide()
    }

    private func pointerMoved() {
        let hadMark = path.hasMark
        guard let step = path.add(NSEvent.mouseLocation) else { return }
        if !hadMark {
            logger.notice("The pointer left the start circle, so the trail is painted")
        }
        if !isShown {
            panel.show(on: path.displayFrame)
            isShown = true
        }
        trail.paint(TrailPart(start: viewPoint(step.start), end: viewPoint(step.end), paintedAt: .now))
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
        CGPoint(x: screenPoint.x - path.displayFrame.minX, y: path.displayFrame.maxY - screenPoint.y)
    }
}
