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
        let (ended, endedContinuation) = AsyncStream.makeStream(of: Void.self)
        process.terminationHandler = { _ in endedContinuation.finish() }
        try process.run()
        let hasEnded = await withTaskCancellationHandler {
            await Self.waitForEnd(ended)
        } onCancel: {
            Self.end(process)
        }
        guard hasEnded else {
            Self.end(process)
            try Task.checkCancellation()
            throw Failure.tookTooLong
        }
        return Output(
            standardOutput: output.fileHandleForReading.readDataToEndOfFile(),
            standardError: error.fileHandleForReading.readDataToEndOfFile()
        )
    }

    private static func waitForEnd(_ ended: AsyncStream<Void>) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in ended {}
                return !Task.isCancelled
            }
            group.addTask {
                try? await Task.sleep(for: timeLimit)
                return false
            }
            let hasEnded = await group.next() ?? false
            group.cancelAll()
            return hasEnded
        }
    }

    // A status command has nothing to save, so SIGKILL ends it at once instead of waiting on SIGTERM.
    private static func end(_ process: Process) {
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
    }
}
