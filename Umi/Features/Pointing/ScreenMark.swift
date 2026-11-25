import CoreGraphics

nonisolated struct ScreenMark: Identifiable, Sendable {
    let id: Int
    let place: MarkPlace
    let arrowTip: CGPoint
    let label: PointLabel?
    let otherMarks: [MarkPlace]
}
