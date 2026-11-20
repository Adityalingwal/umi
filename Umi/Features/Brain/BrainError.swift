nonisolated enum BrainError: Error {
    case claudeNotInstalled
    case claudeDidNotStart
    case notSignedIn
    case limitReached
    case noInternet
    case claudeFailed
    case answerEndedEarly
}
