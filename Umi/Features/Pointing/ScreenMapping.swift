import CoreGraphics

struct ScreenMapping {
    let pictureWidth: Int
    let pictureHeight: Int
    let displayFrame: CGRect

    func screenPlace(for location: MarkLocation) -> MarkPlace? {
        switch location {
        case .point(let point): screenPoint(for: point).map(MarkPlace.ring)
        }
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
