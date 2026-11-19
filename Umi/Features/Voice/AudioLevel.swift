import Foundation

struct AudioLevel: Equatable {
    private static let quietestDecibels = -55.0
    private static let loudestDecibels = -10.0

    let fraction: Double

    static let silent = AudioLevel(fraction: 0)

    private init(fraction: Double) {
        self.fraction = fraction
    }

    init(_ chunk: AudioChunk) {
        guard !chunk.samples.isEmpty else {
            self = .silent
            return
        }
        let meanSquare = chunk.samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(chunk.samples.count)
        let decibels = 10 * log10(max(meanSquare, 1e-12))
        let range = Self.loudestDecibels - Self.quietestDecibels
        fraction = min(max((decibels - Self.quietestDecibels) / range, 0), 1)
    }
}
