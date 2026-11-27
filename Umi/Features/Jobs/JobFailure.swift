nonisolated enum JobFailure: Equatable, Sendable {
    case noInternet
    case notSignedIn
    case limitReached
    case claudeError
    case endedEarly
    case couldNotStart

    var reason: String {
        switch self {
        case .noInternet: "Umi can't reach the internet."
        case .notSignedIn: "Claude Code isn't signed in."
        case .limitReached: "Your Claude usage limit is reached."
        case .claudeError: "Claude reported an error."
        case .endedEarly: "The job stopped before it finished."
        case .couldNotStart: "Claude Code didn't start."
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
