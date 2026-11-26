import Foundation

nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Author: Sendable {
        case user
        case umi
    }

    let id: UUID
    let author: Author
    var text: String
    let time: Date
}
