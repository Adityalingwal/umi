import Testing
@testable import Umi

struct ClaudeSubscriptionTests {
    @Test func claudeStartsWithoutTheAPIKeyFromUmisEnvironment() {
        let umiEnvironment = ["ANTHROPIC_API_KEY": "sk-ant-test", "HOME": "/Users/test", "PATH": "/usr/bin"]

        let claudeEnvironment = ClaudeSubscription.childEnvironment(from: umiEnvironment)

        #expect(claudeEnvironment["ANTHROPIC_API_KEY"] == nil)
        #expect(claudeEnvironment["HOME"] == "/Users/test")
        #expect(claudeEnvironment["PATH"] == "/usr/bin")
    }
}
