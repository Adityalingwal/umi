import Foundation

nonisolated enum CodexLoginStatus {
    private static let chatGPTLine = "Logged in using ChatGPT"
    private static let noLoginLine = "Not logged in"

    // An API-key sign-in bills money, so only a ChatGPT sign-in counts as signed in.
    static func availability(statusOutput: String) -> BrainAvailability {
        let lines = statusOutput.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        if lines.contains(chatGPTLine) {
            return .usable
        }
        if lines.contains(noLoginLine) {
            return .notSignedIn(.noLogin)
        }
        return .notSignedIn(.notChatGPT)
    }
}
