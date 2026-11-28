import Foundation

nonisolated enum CodexTurnRequest {
    @concurrent
    static func line(id: Int, threadID: String, effort: String, question: BrainQuestion) async throws -> Data {
        let context: [[String: Any]] = [question.earlierExchangesText, question.boardBrief, question.jobBrief]
            .compactMap(\.self)
            .map { ["type": "text", "text": $0] }
        let picture = "data:image/jpeg;base64,\(question.screenJPEG.base64EncodedString())"
        let lines = [question.screenSizeText, question.userMark?.text, question.text].compactMap(\.self)
        let input: [[String: Any]] = context + [
            ["type": "image", "url": picture],
            ["type": "text", "text": lines.joined(separator: "\n")]
        ]
        let params: [String: Any] = ["threadId": threadID, "effort": effort, "input": input]
        return try CodexLine.request(id: id, method: "turn/start", params: params)
    }
}
