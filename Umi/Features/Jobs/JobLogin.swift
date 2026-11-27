import Foundation

nonisolated enum JobLogin {
    // A job may spend only the user's Claude subscription: a first-party claude.ai login, nothing else.
    static func isSubscription(statusOutput: Data) -> Bool {
        let status = try? JSONSerialization.jsonObject(with: statusOutput) as? [String: Any]
        return status?["loggedIn"] as? Bool == true
            && status?["authMethod"] as? String == "claude.ai"
            && status?["apiProvider"] as? String == "firstParty"
    }
}
