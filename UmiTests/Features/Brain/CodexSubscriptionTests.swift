import Foundation
import Testing
@testable import Umi

struct CodexSubscriptionTests {
    @Test func codexStartsWithoutTheOpenAIKeysFromUmisEnvironment() {
        let umiEnvironment = [
            "OPENAI_API_KEY": "sk-test",
            "CODEX_API_KEY": "codex-test",
            "CODEX_ACCESS_TOKEN": "token-test",
            "HOME": "/Users/test",
            "PATH": "/usr/bin"
        ]

        let codexEnvironment = CodexSubscription.childEnvironment(
            from: umiEnvironment,
            home: URL(filePath: "/tmp/umi-codex-home")
        )

        #expect(codexEnvironment["OPENAI_API_KEY"] == nil)
        #expect(codexEnvironment["CODEX_API_KEY"] == nil)
        #expect(codexEnvironment["CODEX_ACCESS_TOKEN"] == nil)
        #expect(codexEnvironment["HOME"] == "/Users/test")
        #expect(codexEnvironment["PATH"] == "/usr/bin")
    }
}
