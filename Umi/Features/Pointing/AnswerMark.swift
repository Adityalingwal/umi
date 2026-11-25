import CoreGraphics

struct AnswerMark {
    private static let ringReach = 40.0
    private static let boxReach = 8.0

    let number: Int
    let place: MarkPlace
    let label: PointLabel?

    func isUnder(_ press: CGPoint) -> Bool {
        switch place {
        case .ring(let center):
            hypot(press.x - center.x, press.y - center.y) <= Self.ringReach
        case .box(let frame):
            frame.insetBy(dx: -Self.boxReach, dy: -Self.boxReach).contains(press)
        }
    }
}
