enum JobBrief {
    static func text(for job: Job) -> String {
        switch job.state {
        case .working:
            [
                "The background job: \"\(job.name)\" is running now, so no other job can start until it ends.",
                "Its task: \(job.task)",
                checklist(of: job)
            ].joined(separator: "\n")
        case .done(let result):
            [
                "The background job: the last one, \"\(job.name)\", is done. No job is running.",
                "Its result: \(result)",
                "Its task was: \(job.task)"
            ].joined(separator: "\n")
        case .failed(let failure):
            [
                "The background job: the last one, \"\(job.name)\", did not finish: \(failure.reason)",
                "No job is running.",
                "Its task was: \(job.task)"
            ].joined(separator: "\n")
        }
    }

    private static func checklist(of job: Job) -> String {
        guard !job.steps.isEmpty else { return "It has not written its checklist yet." }
        let steps = job.steps.map { "- [\($0.isDone ? "x" : " ")] \($0.text)" }
        let now = job.currentStepIndex.map { "It is working on: \(job.steps[$0].text)" }
            ?? "Every step is done; it is finishing its report."
        return (["Its checklist, \(job.doneCount) of \(job.steps.count) steps done:"] + steps + [now])
            .joined(separator: "\n")
    }
}
