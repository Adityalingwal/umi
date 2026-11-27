import Foundation
import Testing
@testable import Umi

struct JobLaunchTests {
    @Test func aJobGetsNoToolThatRunsACommandAndNoFolderButItsWorkFolder() throws {
        let workFolder = URL(filePath: "/tmp/umi-test/Jobs/job/work")
        let launch = JobLaunch(
            executableURL: URL(filePath: "/tmp/umi-test/claude"),
            workFolder: workFolder,
            jobID: UUID(),
            appEnvironment: ["HOME": "/tmp/umi-test-home", "PATH": "/usr/bin"]
        )
        let arguments = launch.arguments
        func list(after switchName: String) -> Set<String>? {
            #expect(arguments.count { $0 == switchName } == 1, "\(switchName) is given once")
            return arguments.firstIndex(of: switchName).map { index in
                Set(arguments[index + 1].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }

        let tools = try #require(list(after: "--tools"))
        #expect(!tools.isEmpty)
        #expect(tools.isSubset(of: ["WebSearch", "WebFetch", "Read", "Write", "Edit"]))
        #expect(list(after: "--allowedTools") == ["WebSearch", "WebFetch"])
        #expect(list(after: "--permission-mode") == ["acceptEdits"])
        #expect(list(after: "--permission-prompts") == ["none"])
        #expect(arguments.contains("--restricted"))
        #expect(list(after: "--setting-sources") == [])
        #expect(arguments.contains("--strict-mcp-config"))
        let settingsIndex = try #require(arguments.firstIndex(of: "--settings"))
        let settings = try JSONSerialization.jsonObject(with: Data(arguments[settingsIndex + 1].utf8)) as? [String: Any]
        #expect(settings?.keys.sorted() == ["autoMemoryEnabled"])
        let widening = [
            "--add-dir", "--allowed-tools", "--mcp-config", "--plugin-dir", "--plugin-url", "--agents",
            "--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "--permission-prompt-tool"
        ]
        #expect(widening.allSatisfy { !arguments.contains($0) })
        #expect(!arguments.contains { $0.localizedCaseInsensitiveContains("bypassPermissions") })
        #expect(launch.workFolder == workFolder)
    }
}
