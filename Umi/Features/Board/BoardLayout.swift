import CoreGraphics

struct BoardLayout {
    static let canvas = CGSize(width: 720, height: 460)

    private static let margin = 14.0
    private static let gap = 10.0
    private static let searchStep = 12.0
    private static let searchReach = 264.0
    private static let longestID = 40

    private(set) var marks: [PlacedMark] = []
    private var frames: [String: CGRect] = [:]
    private var ids: Set<String> = []

    init(marks: [PlacedMark] = []) {
        self.marks = marks
        ids = Set(marks.map(\.id))
        for mark in marks {
            frames[mark.id] = mark.shape.solidFrame
        }
    }

    mutating func remove(_ removedIDs: [String]) -> Set<String> {
        var gone = ids.intersection(removedIDs)
        var joined = marks.filter { !gone.contains($0.id) && $0.source.joinedIDs.contains(where: gone.contains) }
        while !joined.isEmpty {
            gone.formUnion(joined.map(\.id))
            joined = marks.filter { !gone.contains($0.id) && $0.source.joinedIDs.contains(where: gone.contains) }
        }
        marks.removeAll { gone.contains($0.id) }
        ids.subtract(gone)
        for id in gone {
            frames[id] = nil
        }
        return gone
    }

    mutating func place(_ newMarks: [BoardMark]) throws -> [PlacedMark] {
        var placed: [PlacedMark] = []
        for mark in newMarks {
            guard !mark.id.isEmpty, mark.id.count <= Self.longestID, ids.insert(mark.id).inserted else {
                throw DrawingError.badMark
            }
            let shape = try shape(for: mark)
            let label = BoardLabel.trimmed(mark.label)
            let placedMark = PlacedMark(id: mark.id, shape: shape, label: label, source: mark)
            if let frame = shape.solidFrame {
                frames[mark.id] = frame
            }
            marks.append(placedMark)
            placed.append(placedMark)
        }
        return placed
    }

    private func shape(for mark: BoardMark) throws -> PlacedShape {
        let label = BoardLabel.trimmed(mark.label)
        switch mark.kind {
        case .box:
            guard let label, let origin = Self.origin(of: mark) else { throw DrawingError.badMark }
            let text = BoardLabel.size(of: label, style: .box, maxWidth: 200)
            let size = CGSize(
                width: max(mark.width ?? 0, text.width + 28, 64),
                height: max(mark.height ?? 0, text.height + 18, 38)
            )
            return .box(free(CGRect(origin: origin, size: size), isRegion: false))
        case .region:
            guard let origin = Self.origin(of: mark), let width = mark.width, let height = mark.height,
                  width > 0, height > 0 else { throw DrawingError.badMark }
            return .region(free(CGRect(origin: origin, size: CGSize(width: width, height: height)), isRegion: true))
        case .text:
            guard let label, let origin = Self.origin(of: mark) else { throw DrawingError.badMark }
            let size = BoardLabel.size(of: label, style: .text, maxWidth: 260)
            return .text(free(CGRect(origin: origin, size: size), isRegion: false))
        case .note:
            guard let label, let origin = Self.origin(of: mark) else { throw DrawingError.badMark }
            let text = BoardLabel.size(of: label, style: .note, maxWidth: 190)
            let size = CGSize(width: text.width + 20, height: text.height + 12)
            let frame = free(CGRect(origin: origin, size: size), isRegion: false)
            let leader = mark.subjectID.flatMap { frames[$0] }.map { Self.segment(from: frame, to: $0) }
            return .note(frame, leader: leader)
        case .arrow, .line:
            guard let startID = mark.startID, let endID = mark.endID, startID != endID,
                  let start = frames[startID], let end = frames[endID] else { throw DrawingError.badMark }
            let segment = Self.segment(from: start, to: end)
            let labelFrame = label.map { freeLabelFrame(for: $0, along: segment) }
            return .connector(segment, hasHead: mark.kind == .arrow, labelFrame: labelFrame)
        }
    }

    private func freeLabelFrame(for label: String, along segment: BoardSegment) -> CGRect {
        let text = BoardLabel.size(of: label, style: .connector, maxWidth: 150)
        let size = CGSize(width: text.width + 10, height: text.height + 4)
        let frames = Self.labelSpots(for: size, along: segment)
        return frames.first { Self.fits($0) && !collides($0, isRegion: false) } ?? frames[0]
    }

    private static let labelSpots = [0.5] + stride(from: 0.05, through: 0.4, by: 0.05).flatMap { [0.5 - $0, 0.5 + $0] }

    // A label laid on a line must leave the line's ends and its arrow head visible; otherwise it goes beside it.
    private static func labelSpots(for size: CGSize, along segment: BoardSegment) -> [CGRect] {
        let deltaX = segment.end.x - segment.start.x
        let deltaY = segment.end.y - segment.start.y
        let length = max(hypot(deltaX, deltaY), 1)
        let along = (abs(deltaX) * size.width + abs(deltaY) * size.height) / length
        let across = (abs(deltaY) * size.width + abs(deltaX) * size.height) / length
        let onLine = labelSpots.filter { spot in
            spot * length - along / 2 >= 6 && spot * length + along / 2 <= length - 16
        }
        let centers: [CGPoint] = onLine.isEmpty
            ? [1.0, -1.0].map { side in
                CGPoint(
                    x: segment.start.x + deltaX / 2 - side * deltaY / length * (across / 2 + 6),
                    y: segment.start.y + deltaY / 2 + side * deltaX / length * (across / 2 + 6)
                )
            }
            : onLine.map { CGPoint(x: segment.start.x + deltaX * $0, y: segment.start.y + deltaY * $0) }
        return centers.map { center in
            CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        }
    }

    private static func origin(of mark: BoardMark) -> CGPoint? {
        guard let originX = mark.originX, let originY = mark.originY, originX.isFinite, originY.isFinite else {
            return nil
        }
        return CGPoint(x: originX, y: originY)
    }

    private func free(_ wanted: CGRect, isRegion: Bool) -> CGRect {
        let start = Self.clamped(wanted)
        guard collides(start, isRegion: isRegion) else { return start }
        for offset in Self.searchOffsets {
            let candidate = start.offsetBy(dx: offset.x, dy: offset.y)
            guard Self.fits(candidate) else { continue }
            if !collides(candidate, isRegion: isRegion) {
                return candidate
            }
        }
        return start
    }

    private func collides(_ frame: CGRect, isRegion: Bool) -> Bool {
        let padded = frame.insetBy(dx: -Self.gap / 2, dy: -Self.gap / 2)
        return marks.contains { mark in
            guard let other = mark.shape.occupiedFrame,
                  padded.intersects(other.insetBy(dx: -Self.gap / 2, dy: -Self.gap / 2)) else { return false }
            let otherIsRegion = if case .region = mark.shape { true } else { false }
            if otherIsRegion, other.contains(frame) {
                return false
            }
            return !(isRegion && frame.contains(other))
        }
    }

    private static let searchOffsets: [CGPoint] = {
        let steps = Int(searchReach / searchStep)
        let offsets = (-steps...steps).flatMap { row in
            (-steps...steps).map { column in CGPoint(x: Double(column) * searchStep, y: Double(row) * searchStep) }
        }
        return offsets.filter { $0 != .zero }.sorted { hypot($0.x, $0.y) < hypot($1.x, $1.y) }
    }()

    private static func clamped(_ frame: CGRect) -> CGRect {
        let width = min(frame.width, canvas.width - 2 * margin)
        let height = min(frame.height, canvas.height - 2 * margin)
        let originX = min(max(frame.minX, margin), canvas.width - margin - width)
        let originY = min(max(frame.minY, margin), canvas.height - margin - height)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private static func fits(_ frame: CGRect) -> Bool {
        frame.minX >= margin && frame.minY >= margin
            && frame.maxX <= canvas.width - margin && frame.maxY <= canvas.height - margin
    }

    private static func segment(from start: CGRect, to end: CGRect) -> BoardSegment {
        let startCenter = CGPoint(x: start.midX, y: start.midY)
        let endCenter = CGPoint(x: end.midX, y: end.midY)
        return BoardSegment(
            start: edgePoint(of: start, toward: endCenter),
            end: edgePoint(of: end, toward: startCenter)
        )
    }

    private static func edgePoint(of frame: CGRect, toward target: CGPoint) -> CGPoint {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let deltaX = target.x - center.x
        let deltaY = target.y - center.y
        guard deltaX != 0 || deltaY != 0 else { return center }
        let reachX = deltaX == 0 ? Double.infinity : (frame.width / 2 + 4) / abs(deltaX)
        let reachY = deltaY == 0 ? Double.infinity : (frame.height / 2 + 4) / abs(deltaY)
        let reach = min(reachX, reachY, 1)
        return CGPoint(x: center.x + deltaX * reach, y: center.y + deltaY * reach)
    }
}
