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
        guard let travel else { return }
        isLanded = true
        guard !travel.isGoingHome else { return }
        marks.append(ScreenMark(id: marks.count, target: travel.target, arrowTip: travel.arrowTip, label: travelLabel))
    }

    func clear() {
        marks = []
        travel = nil
        travelLabel = nil
        isLanded = false
    }
}
