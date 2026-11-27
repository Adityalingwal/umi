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
    private var processGroup: pid_t?

    var processID: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }
    var canTakeMessages: Bool { isInputOpen && process.isRunning }
    var hasOwnProcessGroup: Bool { processGroup != nil }

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
        let group = getpgid(process.processIdentifier)
        if group == process.processIdentifier, group != getpgrp() {
            processGroup = group
        }
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

    // The whole group is signalled, so a child the job started ends with it, also after the job itself has ended.
    // It is signalled only when it is the job's own group, never Umi's.
    func stop() {
        if let processGroup, processGroup != getpgrp() {
            if kill(-processGroup, SIGTERM) == -1, errno != ESRCH {
                logger.error("The job's process group could not be ended: \(errno, privacy: .public)")
            }
        } else if process.isRunning {
            process.terminate()
        }
    }

    // The input is closed only once no write is underway, so a message is never written to a closed handle.
    private func write(_ line: Data) async throws {
        try Task.checkCancellation()
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

    // A question stopped after the hand-off sends nothing.
    @concurrent
    private static func write(_ line: Data, to handle: FileHandle) async throws {
        try Task.checkCancellation()
        try handle.write(contentsOf: line)
    }
}
