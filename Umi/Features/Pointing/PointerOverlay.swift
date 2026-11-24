import Observation

@Observable
final class PointerOverlay {
    private(set) var travel: Travel?
    private(set) var isLanded = false

    func start(_ travel: Travel) {
        self.travel = travel
        isLanded = false
    }

    func land() {
        isLanded = true
    }

    func clear() {
        travel = nil
        isLanded = false
    }
}
