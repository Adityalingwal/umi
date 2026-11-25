import CoreGraphics
import Observation

@Observable
final class PointerOverlay {
    private(set) var marks: [ScreenMark] = []
    private(set) var travel: Travel?
    private(set) var isLanded = false

    func start(_ travel: Travel) {
        self.travel = travel
        isLanded = false
    }

    func land() {
        guard travel != nil else { return }
        isLanded = true
    }

    func landOnMark(numbered number: Int, at place: MarkPlace, label: PointLabel?, avoiding waiting: [MarkPlace]) {
        guard let travel else { return }
        isLanded = true
        marks.append(ScreenMark(
            id: number,
            place: place,
            arrowTip: travel.arrowTip,
            label: label,
            otherMarks: marks.map(\.place) + waiting
        ))
    }

    func remove(marksNumbered numbers: [Int]) {
        marks.removeAll { numbers.contains($0.id) }
    }

    func hideArrow() {
        travel = nil
        isLanded = false
    }

    func clear() {
        marks = []
        travel = nil
        isLanded = false
    }
}
