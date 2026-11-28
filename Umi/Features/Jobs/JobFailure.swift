// The raw value is how a saved job's record names the failure.
nonisolated enum JobFailure: String, Equatable, Sendable {
    case noInternet
    case notSignedIn
    case limitReached
    case claudeError
    case endedEarly
    case noReport
    case umiQuit

    var reason: String {
        switch self {
        case .noInternet: "Umi can't reach the internet."
        case .notSignedIn: "Claude Code isn't signed in."
        case .limitReached: "Your Claude usage limit is reached."
        case .claudeError: "Claude reported an error."
        case .endedEarly: "The job stopped before it finished."
        case .noReport: "The job ended without writing its report."
        case .umiQuit: "Umi quit while the job was working."
        }
    }

    static func from(error: String?, apiError: String?) -> JobFailure {
        switch (error, apiError) {
        case ("authentication_failed", _): .notSignedIn
        case ("rate_limit", _), ("billing_error", _): .limitReached
        case (_, "connection_failed"): .noInternet
        default: .claudeError
        }
    }
}
