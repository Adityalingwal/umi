import AppKit

final class PointerStage {
    private let panel: PointerPanel
    private let overlay: PointerOverlay
    private let displayFrame: CGRect

    init(panel: PointerPanel, overlay: PointerOverlay, displayFrame: CGRect) {
        self.panel = panel
        self.overlay = overlay
        self.displayFrame = displayFrame
    }

    private var bounds: CGRect {
        CGRect(origin: .zero, size: displayFrame.size)
    }

    func fly(to target: CGPoint, label: PointLabel?, startingFrom rest: CGPoint, taking fixed: Duration?) -> Duration {
        let start = overlay.travel?.arrowTip ?? viewPointOnDisplay(rest)
        let end = viewPoint(target)
        let duration = fixed ?? Travel.usualDuration(from: start, to: end)
        let travel = Travel(
            from: start,
            turningFrom: overlay.travel?.angle(at: 1),
            toMarkAt: end,
            within: bounds,
            duration: duration,
            startingAt: .now
        )
        panel.show(on: displayFrame)
        overlay.start(travel, label: label)
        return duration
    }

    func goHome(to rest: CGPoint) -> Duration {
        let home = viewPointOnDisplay(rest)
        let start = overlay.travel?.arrowTip ?? home
        let duration = Travel.usualDuration(from: start, to: home)
        let travel = Travel(
            from: start,
            turningFrom: overlay.travel?.angle(at: 1),
            homeTo: home,
            duration: duration,
            startingAt: .now
        )
        overlay.start(travel, label: nil)
        return duration
    }

    func landOnMark(numbered number: Int, waitingAt targets: [CGPoint]) {
        overlay.landOnMark(numbered: number, avoiding: targets.map(viewPoint))
    }

    func clearMarks(numbered numbers: [Int]) {
        overlay.remove(marksNumbered: numbers)
    }

    func hideArrow() {
        overlay.hideArrow()
        if overlay.marks.isEmpty {
            panel.hide()
        }
    }

    func landHome() {
        overlay.land()
    }

    func keepHome(at rest: CGPoint) {
        guard let last = overlay.travel else { return }
        let home = viewPointOnDisplay(rest)
        let travel = Travel(from: home, turningFrom: last.angle(at: 1), homeTo: home, duration: .zero, startingAt: .now)
        overlay.start(travel, label: nil)
        overlay.land()
    }

    func clear() {
        panel.hide()
        overlay.clear()
    }

    private func viewPointOnDisplay(_ screenPoint: CGPoint) -> CGPoint {
        let point = viewPoint(screenPoint)
        return CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    private func viewPoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - displayFrame.minX, y: displayFrame.maxY - screenPoint.y)
    }
}
