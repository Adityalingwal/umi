import Foundation

nonisolated enum ClaudeStreamEvent {
    case started(apiKeySource: String, model: String)
    case text(String)
    case finished
    case failed
    case other

    init(line: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let type = object["type"] as? String else {
            self = .other
            return
        }
        switch type {
        case "system" where object["subtype"] as? String == "init":
            self = .started(
                apiKeySource: object["apiKeySource"] as? String ?? "unknown",
                model: object["model"] as? String ?? "unknown"
            )
        case "stream_event":
            self = Self.text(in: object["event"] as? [String: Any]).map(Self.text) ?? .other
        case "result":
            self = object["is_error"] as? Bool == true ? .failed : .finished
        default:
            self = .other
        }
    }

    private static func text(in event: [String: Any]?) -> String? {
        guard event?["type"] as? String == "content_block_delta",
              let delta = event?["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta" else {
            return nil
        }
        return delta["text"] as? String
    }
}
