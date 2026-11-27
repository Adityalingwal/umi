// What Umi says when a job ends: the job's own closing sentence is in the user's language, so nothing is added to it.
enum JobEndLine {
    static func text(for job: Job) -> String? {
        switch job.state {
        case .working: nil
        case .done(let result): "\(job.name). \(result)"
        case .failed(let failure): "\(job.name) didn't finish. \(failure.reason)"
        }
    }
}
