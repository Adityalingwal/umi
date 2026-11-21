import Foundation

nonisolated enum CodexCatalog {
    // Codex's own entry for the model, with every tool it would offer the model turned off.
    @concurrent
    static func write(model: String, from cache: URL, to catalog: URL) async throws {
        let data = try Data(contentsOf: cache)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = object["models"] as? [[String: Any]],
              var entry = models.first(where: { $0["slug"] as? String == model }) else {
            throw BrainError.codexCannotUseModel
        }
        entry["tool_mode"] = "direct"
        entry["experimental_supported_tools"] = [String]()
        entry["shell_type"] = "disabled"
        entry["apply_patch_tool_type"] = NSNull()
        entry["supports_search_tool"] = false
        let catalogData = try JSONSerialization.data(withJSONObject: ["models": [entry]])
        try catalogData.write(to: catalog, options: .atomic)
    }
}
