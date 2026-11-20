import Foundation

nonisolated enum ClaudeStreamEvent {
    case started(apiKeySource: String, model: String)
    case text(String)
    case blockEnded
    case apiError(BrainError)
    case connectionLost
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
        case "system" where object["subtype"] as? String == "api_retry" && object["error_status"] is NSNull:
            self = .connectionLost
        case "assistant" where object["error"] is String:
            self = .apiError(Self.failure(error: object["error"] as? String, apiError: object["api_error"] as? String))
        case "stream_event":
            self = Self.streamEvent(object["event"] as? [String: Any])
        case "result":
            self = object["is_error"] as? Bool == true ? .failed : .finished
        default:
            self = .other
        }
    }

    private static func failure(error: String?, apiError: String?) -> BrainError {
        switch (error, apiError) {
        case ("authentication_failed", _): .notSignedIn
        case ("rate_limit", _), ("billing_error", _): .limitReached
        case (_, "connection_failed"): .noInternet
        default: .claudeFailed
        }
    }

    private static func streamEvent(_ event: [String: Any]?) -> ClaudeStreamEvent {
        switch event?["type"] as? String {
        case "content_block_delta": text(in: event).map(Self.text) ?? .other
        case "content_block_stop": .blockEnded
        default: .other
        }
    }

    private static func text(in event: [String: Any]?) -> String? {
        guard let delta = event?["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta" else {
            return nil
        }
        return delta["text"] as? String
    }
}
