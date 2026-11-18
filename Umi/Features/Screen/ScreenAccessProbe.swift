import CoreGraphics
import Foundation

nonisolated struct ScreenAccessProbe: Sendable {
    private static let argument = "--screen-access-probe"

    let executableURL: URL

    static func exitIfRequested(arguments: [String]) {
        guard arguments.dropFirst().first == argument else { return }
        exit(CGPreflightScreenCaptureAccess() ? EXIT_SUCCESS : EXIT_FAILURE)
    }

    @concurrent
    func isGrantedInFreshProcess() async throws -> Bool {
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
