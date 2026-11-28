import CoreGraphics

nonisolated struct ScreenMapping: Sendable {
    let pictureWidth: Int
    let pictureHeight: Int
    let displayFrame: CGRect

    func screenPlace(for location: MarkLocation) -> MarkPlace? {
        switch location {
        case .point(let point): screenPoint(for: point).map(MarkPlace.ring)
        case .box(let box): screenFrame(for: box).map(MarkPlace.box)
        case .stroke(let stroke): screenStroke(for: stroke)
        case .drag(let drag): screenDrag(for: drag)
        case .shape(let shape): screenShape(for: shape)
        }
    }

    func picturePoint(for screenPoint: CGPoint) -> PointLocation? {
        guard displayFrame.width > 0, displayFrame.height > 0 else { return nil }
        let pixelX = (screenPoint.x - displayFrame.minX) * Double(pictureWidth) / displayFrame.width
        let pixelY = (displayFrame.maxY - screenPoint.y) * Double(pictureHeight) / displayFrame.height
        guard (0...Double(pictureWidth)).contains(pixelX), (0...Double(pictureHeight)).contains(pixelY) else {
            return nil
        }
        return PointLocation(pixelX: pixelX, pixelY: pixelY)
    }

    private var picture: CGRect {
        CGRect(x: 0, y: 0, width: pictureWidth, height: pictureHeight)
    }

    private func screenFrame(for box: BoxLocation) -> CGRect? {
        guard pictureWidth > 0, pictureHeight > 0 else { return nil }
        let written = CGRect(
            corner: CGPoint(x: box.corner.pixelX, y: box.corner.pixelY),
            opposite: CGPoint(x: box.oppositeCorner.pixelX, y: box.oppositeCorner.pixelY)
        )
        let kept = written.intersection(picture)
        guard !kept.isNull, kept.width > 0, kept.height > 0 else { return nil }
        return CGRect(
            corner: screenPoint(pixelX: kept.minX, pixelY: kept.minY),
            opposite: screenPoint(pixelX: kept.maxX, pixelY: kept.maxY)
        )
    }

    private func screenStroke(for stroke: StrokeLocation) -> MarkPlace? {
        guard pictureWidth > 0, pictureHeight > 0 else { return nil }
        let start = CGPoint(x: stroke.start.pixelX, y: stroke.start.pixelY)
        let end = CGPoint(x: stroke.end.pixelX, y: stroke.end.pixelY)
        guard start != end, let kept = picture.shareOfLine(from: start, to: end) else { return nil }
        let step = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let enter = kept.lowerBound
        let leave = kept.upperBound
        return .stroke(
            start: screenPoint(pixelX: start.x + step.dx * enter, pixelY: start.y + step.dy * enter),
            end: screenPoint(pixelX: start.x + step.dx * leave, pixelY: start.y + step.dy * leave)
        )
    }

    private func screenDrag(for drag: DragLocation) -> MarkPlace? {
        guard drag.start != drag.end,
              let start = screenPoint(for: drag.start),
              let end = screenPoint(for: drag.end) else {
            return nil
        }
        return .drag(start: start, end: end)
    }

    private func screenShape(for shape: ShapeLocation) -> MarkPlace? {
        guard pictureWidth > 0, pictureHeight > 0 else { return nil }
        let kept = shape.points.map { point in
            CGPoint(
                x: min(max(point.pixelX, picture.minX), picture.maxX),
                y: min(max(point.pixelY, picture.minY), picture.maxY)
            )
        }
        let bounds = CGRect(enclosing: kept)
        guard let start = kept.first, bounds.width > 0, bounds.height > 0 else { return nil }
        return .shape(
            start: screenPoint(pixelX: start.x, pixelY: start.y),
            others: kept.dropFirst().map { screenPoint(pixelX: $0.x, pixelY: $0.y) }
        )
    }

    private func screenPoint(for location: PointLocation) -> CGPoint? {
        guard pictureWidth > 0, pictureHeight > 0,
              (0...Double(pictureWidth)).contains(location.pixelX),
              (0...Double(pictureHeight)).contains(location.pixelY) else {
            return nil
        }
        return screenPoint(pixelX: location.pixelX, pixelY: location.pixelY)
    }

    private func screenPoint(pixelX: Double, pixelY: Double) -> CGPoint {
        CGPoint(
            x: displayFrame.minX + pixelX * displayFrame.width / Double(pictureWidth),
            y: displayFrame.maxY - pixelY * displayFrame.height / Double(pictureHeight)
        )
    }
}
