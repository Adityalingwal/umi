import Foundation

nonisolated struct ClaudeMessage: Sendable {
    let line: Data
    let pictureCount: Int

    init(for question: BrainQuestion) throws {
        let context: [[String: Any]] = [question.earlierExchangesText, question.boardBrief, question.jobBrief]
            .compactMap(\.self)
            .map { ["type": "text", "text": $0] }
        let picture: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": question.screenJPEG.base64EncodedString()
                ]
            ],
            ["type": "text", "text": question.screenSizeText]
        ]
        let mark: [[String: Any]] = question.userMark.map { [["type": "text", "text": $0.text]] } ?? []
        let content = context + picture + mark + [["type": "text", "text": question.text]]
        pictureCount = content.count { $0["type"] as? String == "image" }
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": content]]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(UInt8(ascii: "\n"))
        self.line = line
    }
}
