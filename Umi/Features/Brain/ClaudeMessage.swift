import Foundation

nonisolated enum ClaudeMessage {
    static func line(for question: BrainQuestion) throws -> Data {
        let content: [[String: Any]] = [
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
        let message: [String: Any] = ["type": "user", "message": ["role": "user", "content": content]]
        var line = try JSONSerialization.data(withJSONObject: message)
        line.append(UInt8(ascii: "\n"))
        return line
    }
}
