import Testing
@testable import Umi

struct ClaudeSubscriptionTests {
    @Test func claudeStartsWithoutTheAPIKeyAndBaseURLFromUmisEnvironment() {
        let umiEnvironment = [
            "ANTHROPIC_API_KEY": "sk-ant-test",
            "ANTHROPIC_BASE_URL": "https://proxy.test",
            "HOME": "/Users/test",
            "PATH": "/usr/bin"
        ]

        let claudeEnvironment = ClaudeSubscription.childEnvironment(from: umiEnvironment)

        #expect(claudeEnvironment["ANTHROPIC_API_KEY"] == nil)
        #expect(claudeEnvironment["ANTHROPIC_BASE_URL"] == nil)
        #expect(claudeEnvironment["HOME"] == "/Users/test")
        #expect(claudeEnvironment["PATH"] == "/usr/bin")
    }
}
