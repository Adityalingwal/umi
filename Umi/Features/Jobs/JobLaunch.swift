import Foundation

struct JobLaunch {
    static let tools = ["WebSearch", "WebFetch", "Read", "Write", "Edit"]
    static let toolsWithoutPrompt = ["WebSearch", "WebFetch"]
    private static let effort = "high"
    private static let settings = #"{"autoMemoryEnabled":false}"#
    static let addedVariables = ["DISABLE_TELEMETRY": "1", "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"]

    let executableURL: URL
    let workFolder: URL
    let arguments: [String]
    let environment: [String: String]

    init(executableURL: URL, workFolder: URL, jobID: UUID, appEnvironment: [String: String]) {
        self.executableURL = executableURL
        self.workFolder = workFolder
        arguments = Self.arguments(instructions: JobInstructions.text, sessionID: jobID.uuidString.lowercased())
        environment = ClaudeSubscription.childEnvironment(from: appEnvironment)
            .merging(Self.addedVariables) { _, added in added }
    }

    // The instructions are Umi's own fixed text, so the log shows them as a placeholder.
    var loggedArguments: String {
        Self.arguments(instructions: "<Umi's job instructions>", sessionID: "<job id>")
            .map { $0.isEmpty ? "\"\"" : $0 }
            .joined(separator: " ")
    }

    private static func arguments(instructions: String, sessionID: String) -> [String] {
        [
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--model", ClaudeSubscription.model,
            "--effort", effort,
            "--system-prompt", instructions,
            "--tools", tools.joined(separator: ","),
            "--allowedTools", toolsWithoutPrompt.joined(separator: ","),
            "--permission-mode", "acceptEdits",
            "--permission-prompts", "none",
            "--restricted",
            "--disable-slash-commands",
            "--setting-sources", "",
            "--settings", settings,
            "--strict-mcp-config",
            "--no-session-persistence",
            "--session-id", sessionID
        ]
    }
}
