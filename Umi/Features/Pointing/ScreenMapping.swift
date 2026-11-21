import CoreGraphics

struct ScreenMapping {
    let pictureWidth: Int
    let pictureHeight: Int
    let displayFrame: CGRect

    func screenPoint(for location: PointLocation) -> CGPoint? {
        guard pictureWidth > 0, pictureHeight > 0,
              (0...Double(pictureWidth)).contains(location.pixelX),
              (0...Double(pictureHeight)).contains(location.pixelY) else {
            return nil
        }
        return CGPoint(
            x: displayFrame.minX + location.pixelX * displayFrame.width / Double(pictureWidth),
            y: displayFrame.maxY - location.pixelY * displayFrame.height / Double(pictureHeight)
        )
    }
}
