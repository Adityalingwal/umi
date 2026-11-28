import AppKit
import Testing
@testable import Umi

struct SavedJobsTests {
    @Test func savedJobsComeBackAfterAReloadInOrderWithTheirStateAndResult() async throws {
        let folder = URL.temporaryDirectory.appending(path: "umi-saved-jobs-\(UUID().uuidString)")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var done = Job(id: UUID(), name: "Lakes", task: "Find the largest lakes.", startedAt: start)
        done.end(as: .done(result: "I listed the three largest lakes."))
        var stopped = Job(id: UUID(), name: "Bridges", task: "List old bridges.", startedAt: start + 60)
        stopped.end(as: .stopped)
        let working = Job(id: UUID(), name: "Castles", task: "Compare two castles.", startedAt: start + 120)
        let records = JobRecords(folder: folder)
        for job in [stopped, working, done] {
            try await records.write(job)
        }

        let jobs = Jobs(
            runner: ClaudeJobRunner(
                executable: ClaudeExecutable(fileManager: .default, onlyFolder: folder),
                environment: [:],
                jobsFolder: folder
            ),
            opener: JobFileOpener(workspace: .shared),
            records: JobRecords(folder: folder)
        )
        await jobs.load()

        #expect(jobs.all.map(\.name) == ["Castles", "Bridges", "Lakes"])
        #expect(jobs.all.map(\.state) == [
            .failed(.umiQuit), .stopped, .done(result: "I listed the three largest lakes.")
        ])
        #expect(jobs.all.map(\.task) == ["Compare two castles.", "List old bridges.", "Find the largest lakes."])
        #expect(!jobs.isWorking)
        await jobs.saved()
        try FileManager.default.removeItem(at: folder)
    }
}
