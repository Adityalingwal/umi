import SwiftUI

// A job's page in the window, in the chat's place: its task, what the user added, then its work or its end.
struct JobPage: View {
    let jobID: UUID
    @Environment(Jobs.self) private var jobs

    var body: some View {
        if let job = jobs.job(jobID) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        JobPageHeader(job: job) { jobs.stop(job.id) }
                        JobPageSection(title: "Task") {
                            Text(job.task)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !job.messages.isEmpty {
                            JobPageSection(title: "Your messages") {
                                JobPageMessages(messages: job.messages)
                            }
                        }
                        if job.isWorking {
                            JobPageSection(title: "Progress") {
                                JobPageWork(job: job)
                            }
                            .transition(.opacity)
                        } else {
                            JobPageEnd(job: job)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
                .textSelection(.enabled)
                if job.isWorking {
                    JobMessageField(job: job)
                        .padding(12)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: job.state)
            .animation(.easeOut(duration: 0.2), value: job.messages)
            .task(id: job.state) {
                await jobs.refreshFiles(of: job.id)
            }
        }
    }
}

private struct JobPageHeader: View {
    let job: Job
    let stop: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(job.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                JobPageState(state: job.state)
                if let outcome = JobOutcome(job.state) {
                    Text(outcome.line)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if job.isWorking {
                JobStopButton(stop: stop)
                    .padding(.top, 2)
            }
        }
    }
}

private struct JobPageState: View {
    let state: Job.State

    var body: some View {
        if let outcome = JobOutcome(state) {
            Label(outcome.title, systemImage: outcome.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(outcome.tint)
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Working")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green.opacity(0.9))
            }
        }
    }
}

struct JobPageSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JobPageMessages: View {
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.opacity)
            }
        }
    }
}

private struct JobPageWork: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if job.steps.isEmpty {
                Text("Planning the steps")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(job.steps.enumerated()), id: \.offset) { index, step in
                        JobStepRow(step: step, isCurrent: index == job.currentStepIndex)
                    }
                }
            }
            JobProgress(job: job)
                .frame(maxWidth: 320)
        }
    }
}
