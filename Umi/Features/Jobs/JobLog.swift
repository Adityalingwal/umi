import Foundation
import OSLog

// What the log says about a job's process: its ID, the switches with placeholders and only the tool names Umi gave it.
struct JobLog {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")

    func started(_ launch: JobLaunch, process: JobProcess, jobID: UUID) {
        logger.notice("Started a job on Claude, process \(process.processID, privacy: .public)")
        logger.notice("The job runs in its own process group: \(process.hasOwnProcessGroup, privacy: .public)")
        logger.notice("The job works in Umi's folder: Jobs/\(jobID.uuidString, privacy: .public)/work")
        logger.notice("The job's switches: <claude> \(launch.loggedArguments, privacy: .public)")
        let added = JobLaunch.addedVariables.keys.filter { launch.environment[$0] != nil }.sorted()
        let hasOverride = launch.environment.keys.contains(where: JobLaunch.isProviderOverride)
        logger.notice("The job's environment adds \(added.joined(separator: ", "), privacy: .public)")
        logger.notice("The job's environment holds a key, server or provider: \(hasOverride, privacy: .public)")
    }

    // Only counts and record file names: a record's text is the user's task and the job's result.
    func read(_ reading: JobRecords.Reading, quitCount: Int) {
        let count = reading.jobs.count
        let setAside = JobRecords.setAsideName
        logger.notice("The saved jobs were read: \(count, privacy: .public) jobs")
        if quitCount > 0 {
            logger.notice("Saved jobs working when Umi quit: \(quitCount, privacy: .public), shown as did not finish")
        }
        for id in reading.setAside {
            let file = Self.recordFile(of: id)
            logger.error("A saved job could not be read: \(file, privacy: .public) was set aside")
            logger.notice("The set-aside record is named \(setAside, privacy: .public) and left out")
        }
        for id in reading.unreadable {
            let file = Self.recordFile(of: id)
            logger.error("A saved job could not be read nor set aside: \(file, privacy: .public) was left out")
        }
    }

    func claudeStarted(model: String, apiKeySource: String, tools: [String]) {
        logger.notice("The job's Claude started: model \(model, privacy: .public)")
        logger.notice("The job's Claude key source: \(apiKeySource, privacy: .public)")
        logger.notice("The job's tools: \(Self.loggedNames(tools), privacy: .public)")
    }

    func called(_ names: [String]) {
        logger.notice("The job called \(Self.loggedNames(names), privacy: .public)")
    }

    func refused(_ tools: [String]) {
        let count = tools.count
        let names = Self.loggedNames(tools)
        logger.notice("The job's Claude refused \(count, privacy: .public) tool calls: \(names, privacy: .public)")
    }

    private static func recordFile(of jobID: UUID) -> String {
        "Jobs/\(jobID.uuidString)/\(JobRecords.recordName)"
    }

    // A tool name comes from the job's process, so only the names Umi gave the job are written as they are.
    private static func loggedNames(_ names: [String]) -> String {
        names.map { JobLaunch.tools.contains($0) ? $0 : "other" }.joined(separator: ", ")
    }
}
