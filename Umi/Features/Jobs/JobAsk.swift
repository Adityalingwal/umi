// What an answer's job tag asks Umi to do with the one background job.
nonisolated enum JobAsk: Equatable, Sendable {
    // How a stop or a message went.
    enum Outcome: Equatable, Sendable {
        case done
        case noJobRunning
        case notDelivered
        case cancelled
    }

    case start(JobRequest)
    case stop(say: String?)
    case message(String, say: String?)

    // The brain's own line once it was done, in the user's language; Umi's line when it could not be done.
    func line(after outcome: Outcome) -> String? {
        switch (self, outcome) {
        case (.start, _), (_, .cancelled): nil
        case (.stop(let say), .done): say ?? "I stopped the job."
        case (.stop, _): "No job is running, so there's nothing to stop."
        case (.message(_, let say), .done): say ?? "I passed that on to the job."
        case (.message, .noJobRunning): "No job is running, so the message wasn't passed on."
        case (.message, .notDelivered): "The message couldn't reach the job."
        }
    }
}
