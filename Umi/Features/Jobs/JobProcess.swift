import Foundation
import OSLog

final class JobProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    private var isInputOpen = true
    private var isInputClosed = false
    private var writesUnderway = 0

    var processID: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }
    var canTakeMessages: Bool { isInputOpen && process.isRunning }

    init(launch: JobLaunch) {
        process.executableURL = launch.executableURL
        process.arguments = launch.arguments
        process.environment = launch.environment
        process.currentDirectoryURL = launch.workFolder
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    // A write to a job that has just ended must throw instead of killing Umi with SIGPIPE.
    func run() throws {
        if fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1) == -1 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPIPE)
        }
        try process.run()
    }

    // Input stays open after the task, so a later message can reach the job while it works.
    func send(task: String) async throws -> AsyncStream<String> {
        try await write(Self.userLine(task))
        return JobOutputLines.lines(of: output.fileHandleForReading)
    }

    // The job takes a message in at its next step and carries on with it, without starting over.
    func send(message: String) async throws {
        try await write(Self.userLine(message))
    }

    // The process waits for more input after its result, so closing it lets the job end.
    func endInput() {
        guard isInputOpen else { return }
        isInputOpen = false
        closeInputOnceWritten()
    }

    func stop() {
        if process.isRunning {
            process.terminate()
        }
    }

    // The input is closed only once no write is underway, so a message is never written to a closed handle.
    private func write(_ line: Data) async throws {
        guard isInputOpen else { throw POSIXError(.EPIPE) }
        writesUnderway += 1
        defer {
            writesUnderway -= 1
            closeInputOnceWritten()
        }
        try await Self.write(line, to: input.fileHandleForWriting)
    }

    private func closeInputOnceWritten() {
        guard !isInputOpen, !isInputClosed, writesUnderway == 0 else { return }
        isInputClosed = true
        do {
            try input.fileHandleForWriting.close()
        } catch {
            logger.error("The job's input could not be closed: \((error as NSError).code, privacy: .public)")
        }
    }

    private static func userLine(_ text: String) throws -> Data {
        let message: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": [["type": "text", "text": text]]]
        ]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(UInt8(ascii: "\n"))
        return line
    }

    @concurrent
    private static func write(_ line: Data, to handle: FileHandle) async throws {
        try handle.write(contentsOf: line)
    }
}
