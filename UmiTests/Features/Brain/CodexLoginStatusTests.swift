import Testing
@testable import Umi

struct CodexLoginStatusTests {
    @Test func aCodexSignInWithAnAPIKeyCountsAsNotSignedIn() {
        let statusOutput = """
        API key configured - sk-proj-***abcde
        Authentication is checked when you send a request.
        """

        let availability = CodexLoginStatus.availability(statusOutput: statusOutput, hasLoginFile: true)

        #expect(availability == .notSignedIn(.notChatGPT))
    }
}
