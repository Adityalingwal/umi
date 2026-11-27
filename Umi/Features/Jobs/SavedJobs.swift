import Foundation
import OSLog

// The jobs kept on this Mac: read once when Umi starts, and every change to a job written, in order.
final class SavedJobs {
    private let records: JobRecords
    private let log = JobLog()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")
    private var writing: Task<Void, Never>?
    private var isRead = false

    init(records: JobRecords) {
        self.records = records
    }

    // A job that was working when Umi quit did not finish. It is not carried on, and it ends with no banner and no
    // spoken line; its record is written again as it now reads.
    func read() async -> [Job] {
        guard !isRead else { return [] }
        isRead = true
        let reading: JobRecords.Reading
        do {
            reading = try await records.read()
        } catch {
            logger.error("The saved jobs could not be read: \((error as NSError).code, privacy: .public)")
            return []
        }
        var jobs = reading.jobs
        let quit = jobs.indices.filter { jobs[$0].isWorking }
        for index in quit {
            jobs[index].state = .failed(.umiQuit)
            save(jobs[index])
        }
        log.read(reading, quitCount: quit.count)
        return jobs
    }

    func save(_ job: Job) {
        let previous = writing
        writing = Task { [records, logger] in
            await previous?.value
            do {
                try await records.write(job)
            } catch {
                logger.error("A job's record could not be saved: \((error as NSError).code, privacy: .public)")
            }
        }
    }

    // Only waits for the writes asked for so far.
    func written() async {
        await writing?.value
    }
}
