import Foundation

nonisolated struct StatusCommand: Sendable {
    struct Output: Sendable {
        let standardOutput: Data
        let standardError: Data
    }

    enum Failure: Error {
        case tookTooLong
    }

    private static let timeLimit = Duration.seconds(10)

    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]

    @concurrent
    func run() async throws -> Output {
        try await withThrowingTaskGroup(of: Output?.self) { group in
            group.addTask { try await runToEnd() }
            group.addTask {
                try await Task.sleep(for: Self.timeLimit)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = try await group.next(), let output = first else {
                throw Failure.tookTooLong
            }
            return output
        }
    }

    private func runToEnd() async throws -> Output {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = error
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                process.terminationHandler = { _ in continuation.resume() }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
        try Task.checkCancellation()
        return Output(
            standardOutput: output.fileHandleForReading.readDataToEndOfFile(),
            standardError: error.fileHandleForReading.readDataToEndOfFile()
        )
    }
}
