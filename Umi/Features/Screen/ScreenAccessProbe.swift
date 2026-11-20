import CoreGraphics
import Foundation
import OSLog

nonisolated struct ScreenAccessProbe: Sendable {
    private static let argument = "--screen-access-probe"

    let executableURL: URL

    static func exitIfRequested(arguments: [String]) {
        guard arguments.dropFirst().first == argument else { return }
        exit(CGPreflightScreenCaptureAccess() ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    func isGrantedNow() async -> Bool {
        do {
            return try await isGrantedInFreshProcess()
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Screen")
                .error("Screen access probe failed: \(error.localizedDescription)")
            return CGPreflightScreenCaptureAccess()
        }
    }

    @concurrent
    private func isGrantedInFreshProcess() async throws -> Bool {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = [Self.argument]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationReason == .exit && process.terminationStatus == EXIT_SUCCESS
    }
}
