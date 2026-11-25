import CoreGraphics

struct ScreenMapping {
    let pictureWidth: Int
    let pictureHeight: Int
    let displayFrame: CGRect

    func screenPlace(for location: MarkLocation) -> MarkPlace? {
        switch location {
        case .point(let point): screenPoint(for: point).map(MarkPlace.ring)
        case .box(let box): screenFrame(for: box).map(MarkPlace.box)
        case .stroke(let stroke): screenStroke(for: stroke)
        }
    }

    private func screenFrame(for box: BoxLocation) -> CGRect? {
        guard pictureWidth > 0, pictureHeight > 0 else { return nil }
        let picture = CGRect(x: 0, y: 0, width: pictureWidth, height: pictureHeight)
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
        guard start != end else { return nil }
        let step = CGVector(dx: end.x - start.x, dy: end.y - start.y)
        let limits = [
            (-step.dx, start.x), (step.dx, Double(pictureWidth) - start.x),
            (-step.dy, start.y), (step.dy, Double(pictureHeight) - start.y)
        ]
        var enter = 0.0
        var leave = 1.0
        for (towardEdge, room) in limits {
            if towardEdge == 0 {
                guard room >= 0 else { return nil }
            } else if towardEdge < 0 {
                enter = max(enter, room / towardEdge)
            } else {
                leave = min(leave, room / towardEdge)
            }
        }
        guard enter < leave else { return nil }
        return .stroke(
            start: screenPoint(pixelX: start.x + step.dx * enter, pixelY: start.y + step.dy * enter),
            end: screenPoint(pixelX: start.x + step.dx * leave, pixelY: start.y + step.dy * leave)
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
