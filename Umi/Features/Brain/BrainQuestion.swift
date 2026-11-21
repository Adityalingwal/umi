import Foundation

nonisolated struct BrainQuestion: Sendable {
    let text: String
    let screenJPEG: Data
    let screenWidth: Int
    let screenHeight: Int
    let earlierExchanges: [Exchange]
    let boardBrief: String?

    var screenSizeText: String {
        "The screen picture is \(screenWidth) by \(screenHeight) pixels."
    }

    var earlierExchangesText: String? {
        guard !earlierExchanges.isEmpty else { return nil }
        let turns = earlierExchanges.map { "User: \($0.question)\nUmi: \($0.answer)" }
        return (["Earlier in this conversation, oldest first:"] + turns).joined(separator: "\n\n")
    }
}
