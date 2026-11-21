enum CodexGate {
    static func greet(_ connection: CodexConnection) async throws {
        _ = try await connection.request("initialize", ["clientInfo": ["name": "umi", "version": "1"]])
        try connection.notify("initialized")
    }

    // An API-key sign-in bills money, so only a ChatGPT sign-in may answer.
    static func checkSignIn(_ connection: CodexConnection) async throws {
        let result = try await connection.request("account/read", ["refreshToken": false])
        guard (result["account"] as? [String: Any])?["type"] as? String == "chatgpt" else {
            throw BrainError.notSignedIn(.codex)
        }
    }

    // A Codex that did not take the one-model catalog would offer the model its tools.
    static func checkOnlyModel(_ connection: CodexConnection, model: String) async throws {
        let result = try await connection.request("model/list", ["includeHidden": true])
        let models = (result["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        guard models == [model] else {
            throw BrainError.codexCannotUseModel
        }
    }
}
