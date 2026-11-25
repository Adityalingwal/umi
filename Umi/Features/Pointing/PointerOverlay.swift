import Observation

@Observable
final class PointerOverlay {
    private(set) var travel: Travel?
    private(set) var label: PointLabel?
    private(set) var isLanded = false

    func start(_ travel: Travel, label: PointLabel?) {
        self.travel = travel
        self.label = label
        isLanded = false
    }

    func land() {
        isLanded = true
    }

    func clear() {
        travel = nil
        label = nil
        isLanded = false
    }
}
