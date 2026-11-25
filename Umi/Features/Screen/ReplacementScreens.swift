import Foundation
import OSLog
import Synchronization

nonisolated final class ReplacementScreens: Sendable {
    private let fileURLs: [URL]
    private let taken = Mutex(0)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Screen")

    private init(fileURLs: [URL]) {
        self.fileURLs = fileURLs
    }

    static func atLaunch(defaults: UserDefaults) -> ReplacementScreens? {
        let key = "UmiScreenImage"
        let paths = defaults.stringArray(forKey: key) ?? defaults.string(forKey: key).map { [$0] } ?? []
        guard !paths.isEmpty else { return nil }
        return ReplacementScreens(fileURLs: paths.map { URL(filePath: $0) })
    }

    func next() -> URL {
        let index = taken.withLock { taken in
            defer { taken += 1 }
            return min(taken, fileURLs.count - 1)
        }
        let count = fileURLs.count
        logger.notice("Using replacement screen image \(index + 1, privacy: .public) of \(count, privacy: .public)")
        return fileURLs[index]
    }
}
