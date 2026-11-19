import Foundation

final class ClaudeProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()

    var isRunning: Bool { process.isRunning }

    init(executableURL: URL, arguments: [String], environment: [String: String]) {
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.temporaryDirectory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    func start() throws {
        try process.run()
    }

    func ask(_ question: BrainQuestion) async throws -> AsyncLineSequence<FileHandle.AsyncBytes> {
        try await Self.write(question, to: input.fileHandleForWriting)
        return output.fileHandleForReading.bytes.lines
    }

    func stop() {
        if process.isRunning {
            process.terminate()
        }
    }

    @concurrent
    private static func write(_ question: BrainQuestion, to handle: FileHandle) async throws {
        try handle.write(contentsOf: try ClaudeMessage.line(for: question))
        try handle.close()
    }
}
