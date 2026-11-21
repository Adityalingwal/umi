import Foundation

nonisolated enum ClaudeAuthStatus {
    static func availability(statusOutput: Data) -> BrainAvailability {
        let status = try? JSONSerialization.jsonObject(with: statusOutput) as? [String: Any]
        return status?["loggedIn"] as? Bool == true ? .usable : .notSignedIn(.noLogin)
    }
}
