import Foundation

nonisolated struct TrailPart: Sendable {
    let start: CGPoint
    let end: CGPoint
    let paintedAt: Date
}
