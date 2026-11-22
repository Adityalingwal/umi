nonisolated struct BoardMark: Codable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case box
        case region
        case text
        case note
        case arrow
        case line
    }

    let id: String
    let kind: Kind
    let originX: Double?
    let originY: Double?
    let width: Double?
    let height: Double?
    let label: String?
    let startID: String?
    let endID: String?
    let subjectID: String?

    var joinedIDs: [String] {
        [startID, endID, subjectID].compactMap(\.self)
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, label
        case originX = "x"
        case originY = "y"
        case width = "w"
        case height = "h"
        case startID = "from"
        case endID = "to"
        case subjectID = "about"
    }
}
