import CoreGraphics

nonisolated struct ScreenMark: Identifiable, Sendable {
    let id: Int
    let target: CGPoint
    let arrowTip: CGPoint
    let label: PointLabel?
    let otherRings: [CGPoint]
}
