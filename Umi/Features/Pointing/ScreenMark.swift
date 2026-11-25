import CoreGraphics

struct ScreenMark: Identifiable {
    let id: Int
    let target: CGPoint
    let arrowTip: CGPoint
    let label: PointLabel?
}
