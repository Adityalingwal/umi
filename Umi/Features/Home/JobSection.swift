import SwiftUI

// The running job, or the last finished one until a new one starts, sits above the chat.
struct JobSection: View {
    let showReport: () -> Void
    @Environment(Jobs.self) private var jobs

    var body: some View {
        if let job = jobs.shown {
            VStack(alignment: .leading, spacing: 6) {
                if job.isWorking {
                    Text("1 job working")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.leading, 4)
                }
                JobCard(job: job, showReport: showReport, open: { file in
                    Task { await jobs.open(file) }
                }, stop: {
                    jobs.stop()
                })
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: job)
            .task(id: job.state) {
                await jobs.refreshFiles()
            }
        }
    }
}
