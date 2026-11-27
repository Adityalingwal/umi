// What Umi says when a job ends, in the language the job was asked in. The job's own closing sentence is already in
// that language; the "didn't finish" line is Umi's own, so it has a fixed Hindi form, with English for any other.
enum JobEndLine {
    static func text(for job: Job) -> String? {
        switch job.state {
        case .working, .stopped: nil
        case .done(let result): "\(job.name). \(result)"
        case .failed(let failure): didNotFinish(job.name, failure, in: JobLanguage(task: job.task))
        }
    }

    private static func didNotFinish(_ name: String, _ failure: JobFailure, in language: JobLanguage) -> String {
        switch language {
        case .english: "\(name) didn't finish. \(failure.reason)"
        case .hindi: "\(name) पूरा नहीं हुआ। \(hindiReason(failure))"
        }
    }

    private static func hindiReason(_ failure: JobFailure) -> String {
        switch failure {
        case .noInternet: "Umi internet तक नहीं पहुँच पा रहा।"
        case .notSignedIn: "Claude Code में sign in नहीं है।"
        case .limitReached: "आपकी Claude usage limit पूरी हो गई है।"
        case .claudeError: "Claude ने एक error बताया।"
        case .endedEarly: "Job पूरा होने से पहले रुक गया।"
        case .noReport: "Job ने अपनी report लिखे बिना काम ख़त्म कर दिया।"
        case .umiQuit: "Job चल रहा था तभी Umi बंद हो गया।"
        }
    }
}
