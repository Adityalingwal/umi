import CoreGraphics

struct AnswerMark {
    private static let clickReach = 40.0

    let number: Int
    let target: CGPoint
    let label: PointLabel?

    func isUnder(_ press: CGPoint) -> Bool {
        hypot(press.x - target.x, press.y - target.y) <= Self.clickReach
    }
}
