import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum JPEGEncoder {
    private static let quality = 0.8

    static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        let type = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(data, type, 1, nil) else {
            throw ScreenError.encodingFailed
        }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenError.encodingFailed
        }
        return data as Data
    }
}
