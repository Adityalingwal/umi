nonisolated enum BrainAvailability: Equatable, Sendable {
    case usable
    case notInstalled
    case notSignedIn(SignInProblem)

    enum SignInProblem: Equatable, Sendable {
        case noLogin
        case notChatGPT
        case loginNotInFile
    }
}
