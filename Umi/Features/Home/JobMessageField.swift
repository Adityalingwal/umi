import SwiftUI

// Sends what is typed straight to the working job, the way the brain passes a message on.
struct JobMessageField: View {
    let job: Job
    @Environment(Jobs.self) private var jobs
    @State private var text = ""
    @State private var problem: String?
    @State private var isSending = false

    private var message: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let problem {
                Text(problem)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange.opacity(0.9))
                    .padding(.leading, 14)
                    .transition(.opacity)
            }
            HStack(spacing: 6) {
                TextField(
                    "Message \(job.name)…",
                    text: $text,
                    prompt: Text("Message \(job.name)…").foregroundStyle(.white.opacity(0.4))
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .onSubmit(send)
                SendButton(isEnabled: !message.isEmpty && !isSending, send: send)
            }
            .padding(.leading, 14)
            .padding(.trailing, (AskRow.fieldHeight - SendButton.size) / 2)
            .frame(height: AskRow.fieldHeight)
            .background(.white.opacity(0.1), in: Capsule())
        }
        .onChange(of: text) {
            problem = nil
        }
        .animation(.easeOut(duration: 0.15), value: problem)
    }

    // The text stays until the job has it, so a message that cannot reach the job is not lost.
    private func send() {
        let message = message
        guard !message.isEmpty, !isSending else { return }
        isSending = true
        Task {
            let outcome = await jobs.send(message, to: job.id)
            isSending = false
            guard outcome == .done else {
                problem = JobAsk.message(message, say: nil).line(after: outcome)
                return
            }
            if self.message == message {
                text = ""
            }
        }
    }
}
