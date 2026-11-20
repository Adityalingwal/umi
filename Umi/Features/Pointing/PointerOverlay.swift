import Observation

@Observable
final class PointerOverlay {
    private(set) var travel: Travel?
    private(set) var isLanded = false
    private(set) var isMarked = false

    func start(_ travel: Travel) {
        self.travel = travel
        isLanded = false
        isMarked = false
    }

    func land() {
        isLanded = true
    }

    func mark() {
        isMarked = true
    }

    func clear() {
        travel = nil
        isLanded = false
        isMarked = false
    }
}
