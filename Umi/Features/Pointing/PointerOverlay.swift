import CoreGraphics
import Observation

@Observable
final class PointerOverlay {
    private(set) var marks: [ScreenMark] = []
    private(set) var travel: Travel?
    private(set) var isLanded = false
    private var travelLabel: PointLabel?

    func start(_ travel: Travel, label: PointLabel?) {
        self.travel = travel
        travelLabel = label
        isLanded = false
    }

    func land() {
        guard travel != nil else { return }
        isLanded = true
    }

    func landOnMark(numbered number: Int, avoiding waitingRings: [CGPoint]) {
        guard let travel else { return }
        isLanded = true
        guard !travel.isGoingHome else { return }
        marks.append(ScreenMark(
            id: number,
            target: travel.target,
            arrowTip: travel.arrowTip,
            label: travelLabel,
            otherRings: marks.map(\.target) + waitingRings
        ))
    }

    func remove(marksNumbered numbers: [Int]) {
        marks.removeAll { numbers.contains($0.id) }
    }

    func hideArrow() {
        travel = nil
        travelLabel = nil
        isLanded = false
    }

    func clear() {
        marks = []
        travel = nil
        travelLabel = nil
        isLanded = false
    }
}
