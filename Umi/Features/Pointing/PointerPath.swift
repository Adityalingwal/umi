import AppKit

nonisolated struct PointerPath: Sendable {
    struct Step: Sendable {
        let start: CGPoint
        let end: CGPoint
    }

    // About 12 points is a guess; the design pass sets the final size.
    static let startCircleRadius = 12.0

    let displayFrame: CGRect
    let start: CGPoint
    private(set) var places: [CGPoint] = []
    private var isLastPlaceOnDisplay = true

    init(displayFrame: CGRect, start: CGPoint) {
        self.displayFrame = displayFrame
        self.start = start
    }

    var hasMark: Bool {
        !places.isEmpty
    }

    mutating func add(_ place: CGPoint) -> Step? {
        guard NSMouseInRect(place, displayFrame, false) else {
            isLastPlaceOnDisplay = false
            return nil
        }
        defer { isLastPlaceOnDisplay = true }
        let last = places.last ?? start
        guard hasMark || hypot(place.x - start.x, place.y - start.y) > Self.startCircleRadius else { return nil }
        guard place != last else { return nil }
        if !hasMark {
            places.append(start)
        }
        places.append(place)
        return isLastPlaceOnDisplay ? Step(start: last, end: place) : nil
    }
}
