nonisolated enum CodexArguments {
    static func answering(model: String, catalogPath: String) -> [String] {
        bootstrap(model: model) + ["-c", "model_catalog_json=\(tomlString(catalogPath))"]
    }

    // Started only to have Codex write its own model list into the home; it never runs a turn.
    static func bootstrap(model: String) -> [String] {
        ["app-server"] + switches + features.flatMap { ["--disable", $0] } + ["-c", "model=\(tomlString(model))"]
    }

    static let loginStatus = ["-c", fileStore, "login", "status"]

    private static let fileStore = "cli_auth_credentials_store=\"file\""

    private static let switches = [
        fileStore,
        "project_doc_max_bytes=0",
        "web_search=\"disabled\"",
        "mcp_servers={}",
        "skills.include_instructions=false",
        "skills.bundled.enabled=false",
        "agents.enabled=false",
        "memories.use_memories=false",
        "include_apps_instructions=false",
        "include_permissions_instructions=false",
        "include_collaboration_mode_instructions=false",
        "tools.experimental_request_user_input.enabled=false"
    ].flatMap { ["-c", $0] }

    private static let features = [
        "apps", "memories", "hooks", "plugins", "skill_search", "image_generation", "browser_use",
        "browser_use_external", "computer_use", "in_app_browser", "goals", "multi_agent", "shell_tool",
        "unified_exec", "view_image", "sleep_tool", "code_mode_host", "tool_suggest", "remote_plugin",
        "skill_mcp_dependency_install", "in_app_local_automation", "shell_snapshot"
    ]

    private static func tomlString(_ value: String) -> String {
        let escaped = value
            .replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
