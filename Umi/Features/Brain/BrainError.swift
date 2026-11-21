nonisolated enum BrainError: Error, Equatable {
    case notInstalled(BrainKind)
    case didNotStart(BrainKind)
    case notSignedIn(BrainKind)
    case limitReached(BrainKind)
    case noInternet
    case codexCannotUseModel
    case failed(BrainKind)
    case answerEndedEarly(BrainKind)
}
