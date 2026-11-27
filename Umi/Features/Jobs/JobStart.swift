enum JobStart: Equatable {
    enum Refusal: Equatable {
        case jobRunning
        case claudeNotInstalled
        case claudeNotSignedIn
        case couldNotStart
    }

    case started(JobRequest)
    case refused(Refusal)
    case cancelled

    // What Umi says: the brain's own line for a start, in the user's language, or Umi's line when nothing started.
    var line: String? {
        switch self {
        case .started(let request): request.startLine ?? "I started \(request.name) in the background."
        case .refused(.jobRunning): "A job is already running. Ask again when it's done."
        case .refused(.claudeNotInstalled):
            "Jobs run on Claude Code, which isn't installed. Install it, then sign in with claude auth login."
        case .refused(.claudeNotSignedIn):
            "Jobs run on your Claude subscription, and Claude Code isn't signed in to it. "
                + "Run claude auth login in Terminal."
        case .refused(.couldNotStart): "The job couldn't start this time. Please try again."
        case .cancelled: nil
        }
    }
}
