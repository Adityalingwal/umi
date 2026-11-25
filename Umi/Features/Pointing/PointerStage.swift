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

    func fly(to place: MarkPlace, startingFrom rest: CGPoint, taking fixed: Duration?) -> Duration {
        let start = overlay.travel?.arrowTip ?? viewPointOnDisplay(rest)
        let end = viewPlace(place)
        let duration = fixed ?? Travel.usualDuration(from: start, to: end.center)
        let travel = Travel(
            from: start,
            turningFrom: overlay.travel?.angle(at: 1),
            toMark: end,
            within: bounds,
            duration: duration,
            startingAt: .now
        )
        panel.show(on: displayFrame)
        overlay.start(travel)
        return duration
    }

    func goHome(to rest: CGPoint) -> Duration {
        let home = viewPointOnDisplay(rest)
        let start = overlay.travel?.arrowTip ?? home
        let duration = overlay.travel == nil ? .zero : Travel.usualDuration(from: start, to: home)
        let travel = Travel(
            from: start,
            turningFrom: overlay.travel?.angle(at: 1),
            homeTo: home,
            duration: duration,
            startingAt: .now
        )
        overlay.start(travel)
        return duration
    }

    func landOnMark(numbered number: Int, at place: MarkPlace, label: PointLabel?, waitingAt places: [MarkPlace]) {
        overlay.landOnMark(numbered: number, at: viewPlace(place), label: label, avoiding: places.map(viewPlace))
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
        overlay.start(travel)
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

    private func viewPlace(_ screenPlace: MarkPlace) -> MarkPlace {
        screenPlace.mapped(viewPoint)
    }

    private func viewPoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - displayFrame.minX, y: displayFrame.maxY - screenPoint.y)
    }
}
