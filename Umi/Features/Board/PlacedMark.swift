import CoreGraphics

struct BoardSegment {
    let start: CGPoint
    let end: CGPoint
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

    var occupiedFrame: CGRect? {
        if case let .connector(_, _, labelFrame) = self {
            return labelFrame
        }
        return solidFrame
    }
}

struct PlacedMark: Identifiable {
    let id: String
    let shape: PlacedShape
    let label: String?
    let source: BoardMark

    var asPlaced: BoardMark {
        let frame = shape.solidFrame
        return BoardMark(
            id: id,
            kind: source.kind,
            originX: frame.map { $0.minX.rounded() },
            originY: frame.map { $0.minY.rounded() },
            width: frame.map { $0.width.rounded() },
            height: frame.map { $0.height.rounded() },
            label: label,
            startID: source.startID,
            endID: source.endID,
            subjectID: source.subjectID
        )
    }
}
