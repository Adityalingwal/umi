import SwiftUI

struct JobCard: View {
    let job: Job
    let showReport: () -> Void
    let open: (JobFile) -> Void
    let stop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(job.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if job.isWorking {
                    JobStopButton(stop: stop)
                }
            }
            if let outcome = JobOutcome(job.state) {
                JobEnd(outcome: outcome, showReport: showReport)
                if !job.files.isEmpty {
                    JobFileList(files: job.files, open: open)
                }
            } else {
                JobWork(job: job)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct JobWork: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if job.steps.isEmpty {
                Text("Planning the steps")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                JobChecklist(steps: job.steps, current: job.currentStepIndex)
            }
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
}

// A long checklist scrolls inside the card, so the chat below keeps its room; the current step stays in view.
private struct JobChecklist: View {
    private static let visibleRows = 6
    private static let rowHeight = 17.0

    let steps: [JobStep]
    let current: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        JobStepRow(step: step, isCurrent: index == current)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
            .frame(height: Double(min(steps.count, Self.visibleRows)) * (Self.rowHeight + 2))
            .onChange(of: current, initial: true) { _, current in
                guard let current else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(current, anchor: .center)
                }
            }
        }
    }
}

private struct JobStepRow: View {
    let step: JobStep
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(step.isDone ? .green.opacity(0.8) : .white.opacity(isCurrent ? 0.9 : 0.4))
            Text(step.text)
                .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                .strikethrough(step.isDone)
                .foregroundStyle(.white.opacity(step.isDone ? 0.45 : (isCurrent ? 0.95 : 0.7)))
                .lineLimit(1)
        }
        .frame(height: 17)
    }
}

private struct JobEnd: View {
    let outcome: JobOutcome
    let showReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(outcome.title, systemImage: outcome.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(outcome.tint)
                Spacer(minLength: 0)
                if outcome.hasReport {
                    FullReportButton(show: showReport)
                }
            }
            Text(outcome.line)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
