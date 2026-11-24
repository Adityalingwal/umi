import AppKit

final class PointerStage {
    private static let fadeOut = Duration.milliseconds(200)

    private let panel: PointerPanel
    private let overlay: PointerOverlay
    private let displayFrame: CGRect
    private var hiding: Task<Void, Never>?

    init(panel: PointerPanel, overlay: PointerOverlay, displayFrame: CGRect) {
        self.panel = panel
        self.overlay = overlay
        self.displayFrame = displayFrame
    }

    func usualTravelTime(from rest: CGPoint, to target: CGPoint) -> Duration {
        Travel.usualDuration(from: viewPoint(rest), to: viewPoint(target))
    }

    func travel(from rest: CGPoint, to target: CGPoint, taking duration: Duration) {
        let bounds = CGRect(origin: .zero, size: displayFrame.size)
        let restPoint = viewPoint(rest)
        let start = CGPoint(
            x: min(max(restPoint.x, bounds.minX), bounds.maxX),
            y: min(max(restPoint.y, bounds.minY), bounds.maxY)
        )
        let travel = Travel(from: start, to: viewPoint(target), within: bounds, duration: duration, startingAt: .now)
        panel.show(on: displayFrame)
        overlay.start(travel)
    }

    func land() {
        overlay.land()
    }

    func clear(fading: Bool) {
        if !fading {
            panel.hide()
        }
        overlay.clear()
        if fading {
            hideAfterFade()
        }
    }

    private func hideAfterFade() {
        hiding = Task { [panel, overlay] in
            try? await Task.sleep(for: Self.fadeOut)
            guard overlay.travel == nil else { return }
            panel.hide()
        }
    }

    private func viewPoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - displayFrame.minX, y: displayFrame.maxY - screenPoint.y)
    }
}
