import Foundation

nonisolated struct ChatMessage: Identifiable, Equatable, Sendable {
    enum Author: String, Codable, Sendable {
        case user
        case umi
    }

    // An answer has the way of the question it answers.
    enum Way: String, Codable, Sendable {
        case spoken
        case typed
    }

    let id: UUID
    let author: Author
    var text: String
    let time: Date
    let way: Way
    let isFailureLine: Bool
}
