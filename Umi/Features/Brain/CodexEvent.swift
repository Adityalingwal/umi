nonisolated enum CodexEvent: Sendable {
    case text(turnID: String, piece: String)
    case itemStarted(turnID: String, type: String)
    case error(turnID: String, BrainError, willRetry: Bool)
    case turnEnded(turnID: String, status: String, BrainError?)
    case other

    var turnID: String? {
        switch self {
        case .text(let turnID, _), .itemStarted(let turnID, _), .error(let turnID, _, _), .turnEnded(let turnID, _, _):
            turnID
        case .other:
            nil
        }
    }

    init(method: String, params: [String: Any]) {
        let turnID = params["turnId"] as? String
        switch method {
        case "item/agentMessage/delta":
            self = Self.text(turnID: turnID, piece: params["delta"] as? String)
        case "item/started":
            let item = params["item"] as? [String: Any]
            self = Self.itemStarted(turnID: turnID, type: item?["type"] as? String)
        case "error":
            let failure = Self.failure(params["error"] as? [String: Any])
            let willRetry = params["willRetry"] as? Bool ?? false
            self = turnID.map { .error(turnID: $0, failure, willRetry: willRetry) } ?? .other
        case "turn/completed":
            self = Self.turnEnded(params["turn"] as? [String: Any])
        default:
            self = .other
        }
    }

    private static func text(turnID: String?, piece: String?) -> CodexEvent {
        guard let turnID, let piece else { return .other }
        return .text(turnID: turnID, piece: piece)
    }

    private static func itemStarted(turnID: String?, type: String?) -> CodexEvent {
        guard let turnID, let type else { return .other }
        return .itemStarted(turnID: turnID, type: type)
    }

    private static func turnEnded(_ turn: [String: Any]?) -> CodexEvent {
        guard let turnID = turn?["id"] as? String, let status = turn?["status"] as? String else { return .other }
        let error = turn?["error"] as? [String: Any]
        return .turnEnded(turnID: turnID, status: status, error.map(failure))
    }

    // Codex sends the error kind either as a plain name or as an object with one key.
    private static func failure(_ error: [String: Any]?) -> BrainError {
        let info = error?["codexErrorInfo"]
        let kind = info as? String ?? (info as? [String: Any])?.keys.first
        switch kind {
        case "unauthorized": return .notSignedIn(.codex)
        case "usageLimitExceeded", "rateLimitExceeded": return .limitReached(.codex)
        case "httpConnectionFailed", "responseStreamConnectionFailed": return .noInternet
        case "modelNotFound": return .codexCannotUseModel
        default: return .failed(.codex)
        }
    }
}
