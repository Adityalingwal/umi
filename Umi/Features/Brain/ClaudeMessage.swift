import Foundation

nonisolated struct ClaudeMessage: Sendable {
    let line: Data
    let pictureCount: Int

    init(for question: BrainQuestion) throws {
        let content = Self.history(question.earlierExchanges) + [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": question.screenJPEG.base64EncodedString()
                ]
            ],
            [
                "type": "text",
                "text": "The screen picture is \(question.screenWidth) by \(question.screenHeight) pixels."
            ],
            ["type": "text", "text": question.text]
        ]
        pictureCount = content.count { $0["type"] as? String == "image" }
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": content]]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(UInt8(ascii: "\n"))
        self.line = line
    }

    private static func history(_ exchanges: [Exchange]) -> [[String: Any]] {
        guard !exchanges.isEmpty else { return [] }
        let turns = exchanges.map { "User: \($0.question)\nUmi: \($0.answer)" }
        let text = (["Earlier in this conversation, oldest first:"] + turns).joined(separator: "\n\n")
        return [["type": "text", "text": text]]
    }
}
