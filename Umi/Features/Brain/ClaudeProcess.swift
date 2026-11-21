import Foundation
import OSLog

final class ClaudeProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")

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
        let message = try await Self.write(question, to: input.fileHandleForWriting)
        let bytes = message.line.count
        let pictures = message.pictureCount
        let earlier = question.earlierExchanges.count
        logger.notice("Sent Claude \(bytes, privacy: .public) bytes with \(pictures, privacy: .public) screen pictures")
        logger.notice("The message carried \(earlier, privacy: .public) earlier exchanges")
        return output.fileHandleForReading.bytes.lines
    }

    func stop() {
        if process.isRunning {
            process.terminate()
        }
    }

    @concurrent
    private static func write(_ question: BrainQuestion, to handle: FileHandle) async throws -> ClaudeMessage {
        let message = try ClaudeMessage(for: question)
        try handle.write(contentsOf: message.line)
        try handle.close()
        return message
    }
}
