import Foundation

struct Job: Identifiable, Equatable {
    enum State: Equatable {
        case working
        case done(result: String)
        case failed(JobFailure)
        case stopped
    }

    let id: UUID
    let name: String
    let task: String
    var steps: [JobStep] = []
    var messages: [String] = []
    var state = State.working
    var files: [JobFile] = []

    var isWorking: Bool {
        state == .working
    }

    var doneCount: Int {
        steps.count { $0.isDone }
    }

    var currentStepIndex: Int? {
        steps.firstIndex { !$0.isDone }
    }

    // Every step is done and the job has not ended yet.
    var isFinalizing: Bool {
        isWorking && !steps.isEmpty && currentStepIndex == nil
    }
}
