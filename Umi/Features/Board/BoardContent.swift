import Foundation
import Observation

struct ShownMark: Identifiable {
    let mark: PlacedMark
    let appearsAt: Date
    var disappearsAt: Date?

    var id: String { mark.id }
}

@Observable
final class BoardContent {
    static let markStagger = 0.14

    private(set) var marks: [ShownMark] = []
    private(set) var isWaiting = false

    var summary: String {
        marks.filter { $0.disappearsAt == nil }.compactMap(\.mark.label).joined(separator: ", ")
    }

    var isEmpty: Bool {
        !marks.contains { $0.disappearsAt == nil }
    }

    func startDrawing() {
        marks = []
        isWaiting = true
    }

    func startEditing(_ drawing: Drawing) {
        show(drawing)
        isWaiting = true
    }

    func reveal(_ rows: [DrawingRow]) {
        let now = Date.now
        var index = 0
        for row in rows {
            for position in marks.indices
            where marks[position].disappearsAt == nil && row.removedIDs.contains(marks[position].id) {
                marks[position].disappearsAt = now
            }
            for mark in row.added {
                marks.append(ShownMark(mark: mark, appearsAt: now.addingTimeInterval(Double(index) * Self.markStagger)))
                index += 1
            }
        }
        isWaiting = false
    }

    func show(_ drawing: Drawing) {
        marks = drawing.marks.map { ShownMark(mark: $0, appearsAt: .distantPast) }
        isWaiting = false
    }

    func clear() {
        marks = []
        isWaiting = false
    }
}
