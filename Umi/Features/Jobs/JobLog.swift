import Foundation
import OSLog

// What the log says about a job's process: its ID, the switches with placeholders and only the tool names Umi gave it.
struct JobLog {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")

    func started(_ launch: JobLaunch, processID: Int32, jobID: UUID) {
        logger.notice("Started a job on Claude, process \(processID, privacy: .public)")
        logger.notice("The job works in Umi's folder: Jobs/\(jobID.uuidString, privacy: .public)/work")
        logger.notice("The job's switches: <claude> \(launch.loggedArguments, privacy: .public)")
        let added = JobLaunch.addedVariables.keys.filter { launch.environment[$0] != nil }.sorted()
        let hasOverride = launch.environment.keys.contains(where: JobLaunch.isProviderOverride)
        logger.notice("The job's environment adds \(added.joined(separator: ", "), privacy: .public)")
        logger.notice("The job's environment holds a key, server or provider: \(hasOverride, privacy: .public)")
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

    // A tool name comes from the job's process, so only the names Umi gave the job are written as they are.
    private static func loggedNames(_ names: [String]) -> String {
        names.map { JobLaunch.tools.contains($0) ? $0 : "other" }.joined(separator: ", ")
    }
}
