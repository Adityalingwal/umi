import Foundation

nonisolated enum DrawingLine {
    case newDrawing(String)
    case edit(String)
    case reopen
    case part(say: String, marks: [BoardMark], removedIDs: [String])

    private static let longestTitle = 60
    private static let longestSay = 300

    static func decode(_ text: String) throws -> DrawingLine {
        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: Data(text.utf8))
        } catch {
            throw DrawingError.unreadableLine
        }
        let headers = [wire.drawing, wire.edit, wire.reopen].compactMap(\.self)
        if let say = wire.say?.trimmingCharacters(in: .whitespacesAndNewlines), headers.isEmpty {
            guard !say.isEmpty, say.count <= longestSay else { throw DrawingError.unreadableLine }
            return .part(say: say, marks: wire.add ?? [], removedIDs: wire.remove ?? [])
        }
        guard wire.say == nil, headers.count == 1,
              let title = headers.first?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty
        else { throw DrawingError.unreadableLine }
        let shortTitle = String(title.prefix(longestTitle))
        if wire.reopen != nil {
            return .reopen
        }
        return wire.edit == nil ? .newDrawing(shortTitle) : .edit(shortTitle)
    }
}

private nonisolated struct Wire: Decodable {
    let drawing: String?
    let edit: String?
    let reopen: String?
    let say: String?
    let add: [BoardMark]?
    let remove: [String]?
}
