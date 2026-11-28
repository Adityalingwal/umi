import Foundation

// The user's mark in the form both brains read best (#97, form B): the path's box and a few points along it.
nonisolated struct UserMark: Sendable {
    private static let pointCount = 8

    let text: String

    init?(places: [CGPoint]) {
        guard !places.isEmpty else { return nil }
        let xValues = places.map(\.x)
        let yValues = places.map(\.y)
        let low = (x: Int((xValues.min() ?? 0).rounded(.down)), y: Int((yValues.min() ?? 0).rounded(.down)))
        let high = (x: Int((xValues.max() ?? 0).rounded(.up)), y: Int((yValues.max() ?? 0).rounded(.up)))
        let corners = "x1=\"\(low.x)\" y1=\"\(low.y)\" x2=\"\(high.x)\" y2=\"\(high.y)\""
        let points = Self.thinned(places).map { "\($0.x),\($0.y)" }.joined(separator: " ")
        text = "The user's mark, in pixel coordinates of the screen picture: the box around the path is \(corners), "
            + "and points along the path, in order, are \(points)."
    }

    // Evenly spaced along the path's length, the first and last place included; a short path gives fewer points.
    private static func thinned(_ places: [CGPoint]) -> [(x: Int, y: Int)] {
        var lengths = [0.0]
        for (start, end) in zip(places, places.dropFirst()) {
            lengths.append((lengths.last ?? 0) + hypot(end.x - start.x, end.y - start.y))
        }
        let total = lengths.last ?? 0
        var points: [(x: Int, y: Int)] = []
        for index in 0..<pointCount {
            let target = total * Double(index) / Double(pointCount - 1)
            let place = places[lengths.firstIndex { $0 >= target } ?? places.count - 1]
            let point = (x: Int(place.x.rounded()), y: Int(place.y.rounded()))
            if points.last.map({ $0 != point }) ?? true {
                points.append(point)
            }
        }
        return points
    }
}
