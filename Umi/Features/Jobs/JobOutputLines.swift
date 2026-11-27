import Foundation
import Synchronization

// FileHandle's async bytes read on one shared actor, so a job that stays silent would hold up every brain answer.
nonisolated enum JobOutputLines {
    static func lines(of handle: FileHandle) -> AsyncStream<String> {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self)
        let pending = PendingBytes()
        handle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                if let rest = pending.rest() {
                    continuation.yield(rest)
                }
                continuation.finish()
                return
            }
            pending.add(data).forEach { continuation.yield($0) }
        }
        continuation.onTermination = { _ in
            handle.readabilityHandler = nil
        }
        return lines
    }
}

private nonisolated final class PendingBytes: Sendable {
    private let bytes = Mutex(Data())

    func add(_ data: Data) -> [String] {
        bytes.withLock { bytes in
            bytes.append(data)
            var lines: [String] = []
            while let end = bytes.firstIndex(of: UInt8(ascii: "\n")) {
                if let line = String(bytes: bytes[bytes.startIndex..<end], encoding: .utf8) {
                    lines.append(line)
                }
                bytes.removeSubrange(bytes.startIndex...end)
            }
            return lines
        }
    }

    func rest() -> String? {
        bytes.withLock { bytes in
            defer { bytes = Data() }
            return bytes.isEmpty ? nil : String(bytes: bytes, encoding: .utf8)
        }
    }
}
