import Foundation

nonisolated enum DrawingLine {
    case title(String)
    case part(say: String, marks: [BoardMark])

    private static let longestTitle = 60
    private static let longestSay = 300

    static func decode(_ text: String) throws -> DrawingLine {
        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: Data(text.utf8))
        } catch {
            throw DrawingError.unreadableLine
        }
        if let say = wire.say?.trimmingCharacters(in: .whitespacesAndNewlines), wire.drawing == nil {
            guard !say.isEmpty, say.count <= longestSay else { throw DrawingError.unreadableLine }
            return .part(say: say, marks: wire.add ?? [])
        }
        if let title = wire.drawing?.trimmingCharacters(in: .whitespacesAndNewlines), wire.say == nil, !title.isEmpty {
            return .title(String(title.prefix(longestTitle)))
        }
        throw DrawingError.unreadableLine
    }
}

private nonisolated struct Wire: Decodable {
    let drawing: String?
    let say: String?
    let add: [BoardMark]?
}
