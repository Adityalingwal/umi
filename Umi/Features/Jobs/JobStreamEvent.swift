import Foundation

nonisolated enum JobStreamEvent {
    case started(model: String, apiKeySource: String, tools: [String])
    case toolCalls(names: [String], checklist: String?)
    case apiError(JobFailure)
    case connectionLost
    case finished(result: String, refusedTools: [String])
    case failed(refusedTools: [String])
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
                model: object["model"] as? String ?? "unknown",
                apiKeySource: object["apiKeySource"] as? String ?? "unknown",
                tools: (object["tools"] as? [String] ?? []).sorted()
            )
        case "system" where object["subtype"] as? String == "api_retry" && object["error_status"] is NSNull:
            self = .connectionLost
        case "assistant" where object["error"] is String:
            self = .apiError(.from(error: object["error"] as? String, apiError: object["api_error"] as? String))
        case "assistant":
            self = Self.toolCalls(in: object["message"] as? [String: Any])
        case "result":
            let refused = (object["permission_denials"] as? [[String: Any]] ?? []).map {
                $0["tool_name"] as? String ?? "unknown"
            }
            if object["is_error"] as? Bool == true {
                self = .failed(refusedTools: refused)
            } else {
                self = .finished(result: object["result"] as? String ?? "", refusedTools: refused)
            }
        default:
            self = .other
        }
    }

    private static func toolCalls(in message: [String: Any]?) -> JobStreamEvent {
        let calls = (message?["content"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "tool_use" }
        guard !calls.isEmpty else { return .other }
        let names = calls.map { $0["name"] as? String ?? "unknown" }
        let checklist = calls.last { call in
            let input = call["input"] as? [String: Any]
            let path = input?["file_path"] as? String ?? ""
            let isChecklist = URL(filePath: path).lastPathComponent == JobInstructions.checklistName
            return call["name"] as? String == "Write" && isChecklist
        }
        return .toolCalls(names: names, checklist: (checklist?["input"] as? [String: Any])?["content"] as? String)
    }
}
