import Foundation
import OSLog

final class JobProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    private var isInputOpen = true

    var processID: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }

    init(launch: JobLaunch) {
        process.executableURL = launch.executableURL
        process.arguments = launch.arguments
        process.environment = launch.environment
        process.currentDirectoryURL = launch.workFolder
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    // Input stays open after the task, so a later message can reach the job while it works.
    func start(task: String) async throws -> AsyncLineSequence<FileHandle.AsyncBytes> {
        try process.run()
        try await Self.write(Self.userLine(task), to: input.fileHandleForWriting)
        return output.fileHandleForReading.bytes.lines
    }

    // The process waits for more input after its result, so closing it lets the job end.
    func endInput() {
        guard isInputOpen else { return }
        isInputOpen = false
        do {
            try input.fileHandleForWriting.close()
        } catch {
            logger.error("The job's input could not be closed: \((error as NSError).code, privacy: .public)")
        }
    }

    func stop() {
        if process.isRunning {
            process.terminate()
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
