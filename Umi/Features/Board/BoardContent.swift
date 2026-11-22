import Foundation
import Observation

struct ShownMark: Identifiable {
    let mark: PlacedMark
    let appearsAt: Date

    var id: String { mark.id }
}

@Observable
final class BoardContent {
    static let markStagger = 0.14

    private(set) var marks: [ShownMark] = []
    private(set) var isWaiting = false

    var summary: String {
        marks.compactMap(\.mark.label).joined(separator: ", ")
    }

    func startDrawing() {
        marks = []
        isWaiting = true
    }

    func reveal(_ newMarks: [PlacedMark]) {
        guard !newMarks.isEmpty else { return }
        let now = Date.now
        marks += newMarks.enumerated().map { index, mark in
            ShownMark(mark: mark, appearsAt: now.addingTimeInterval(Double(index) * Self.markStagger))
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
