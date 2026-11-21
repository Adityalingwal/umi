nonisolated enum BrainKind: String, CaseIterable, Sendable {
    case claude
    case codex

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}
