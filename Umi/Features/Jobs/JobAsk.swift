// What an answer's job tag asks Umi to do with the one background job.
nonisolated enum JobAsk: Equatable, Sendable {
    case start(JobRequest)
    case stop(say: String?)
    case message(String, say: String?)

    // The brain's own line once it was done, in the user's language; Umi's line when no job was running.
    func line(isDone: Bool) -> String? {
        switch self {
        case .start: nil
        case .stop(let say): isDone ? say ?? "I stopped the job." : "No job is running, so there's nothing to stop."
        case .message(_, let say):
            isDone ? say ?? "I passed that on to the job." : "No job is running, so the message wasn't passed on."
        }
    }
}
