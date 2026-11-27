import Foundation

nonisolated struct ChatFile: Sendable {
    enum Reading: Sendable {
        case noFile
        case messages([ChatMessage])
        case setAside
        case unreadable
    }

    private struct SavedMessage: Codable {
        let author: ChatMessage.Author
        let text: String
        let time: Date
        let way: ChatMessage.Way
    }

    private let folder: URL
    private var file: URL { folder.appending(path: "chat.json") }
    private var setAsideFile: URL { folder.appending(path: "chat-unreadable.json") }

    init(folder: URL) {
        self.folder = folder
    }

    @concurrent
    func read() async -> Reading {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: file.path) else { return .noFile }
        do {
            let data = try Data(contentsOf: file)
            let saved = try Self.decoder.decode([SavedMessage].self, from: data)
            return .messages(saved.map(Self.message(from:)))
        } catch {
            return setAside(fileManager: fileManager)
        }
    }

    @concurrent
    func write(_ messages: [ChatMessage]) async throws {
        let saved = messages.map { SavedMessage(author: $0.author, text: $0.text, time: $0.time, way: $0.way) }
        let data = try Self.encoder.encode(saved)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
    }

    @concurrent
    func clear() async throws {
        try await write([])
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: setAsideFile.path) else { return }
        try fileManager.removeItem(at: setAsideFile)
    }

    // One set-aside name, so a newer unreadable file replaces an older one and Clear chat has one file to delete.
    private func setAside(fileManager: FileManager) -> Reading {
        do {
            if fileManager.fileExists(atPath: setAsideFile.path) {
                try fileManager.removeItem(at: setAsideFile)
            }
            try fileManager.moveItem(at: file, to: setAsideFile)
            return .setAside
        } catch {
            return .unreadable
        }
    }

    private static func message(from saved: SavedMessage) -> ChatMessage {
        ChatMessage(
            id: UUID(),
            author: saved.author,
            text: saved.text,
            time: saved.time,
            way: saved.way,
            isFailureLine: false
        )
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
