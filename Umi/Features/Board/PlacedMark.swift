import CoreGraphics

struct BoardSegment {
    let start: CGPoint
    let end: CGPoint

    var middle: CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
}

enum PlacedShape {
    case box(CGRect)
    case region(CGRect)
    case text(CGRect)
    case note(CGRect, leader: BoardSegment?)
    case connector(BoardSegment, hasHead: Bool, labelFrame: CGRect?)

    var solidFrame: CGRect? {
        switch self {
        case .box(let frame), .region(let frame), .text(let frame), .note(let frame, _): frame
        case .connector: nil
        }
    }
}

struct PlacedMark: Identifiable {
    let id: String
    let shape: PlacedShape
    let label: String?
}
