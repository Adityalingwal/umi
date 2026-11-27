import SwiftUI

// The thin track with the count of done steps; the total may grow while the job works.
struct JobProgress: View {
    let job: Job

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: Double(job.doneCount), total: Double(max(job.steps.count, 1)))
                .progressViewStyle(.linear)
                .controlSize(.mini)
                .tint(.green)
            Text("\(job.doneCount)/\(job.steps.count)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
            if job.isFinalizing {
                Text("Finalizing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
