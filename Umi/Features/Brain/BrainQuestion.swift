import Foundation

nonisolated struct BrainQuestion: Sendable {
    let text: String
    let screenJPEG: Data
    let screenWidth: Int
    let screenHeight: Int
    let earlierExchanges: [Exchange]
}
