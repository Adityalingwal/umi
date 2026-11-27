import SwiftUI

// An ended job's page: its one line, then for a done job its report, then an Open control for each file it made.
struct JobPageEnd: View {
    let job: Job
    @Environment(Jobs.self) private var jobs

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let outcome = JobOutcome(job.state) {
                Text(outcome.line)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .done = job.state {
                JobPageSection(title: "Report") {
                    JobPageReport(jobID: job.id)
                }
            }
            if !job.files.isEmpty {
                JobPageSection(title: "Files") {
                    JobFileList(files: job.files) { file in
                        Task { await jobs.open(file, of: job.id) }
                    }
                }
            }
        }
    }
}

// Read when the page shows a done job, so a page open while its job ends shows the report without a reload.
private struct JobPageReport: View {
    let jobID: UUID
    @Environment(Jobs.self) private var jobs
    @State private var report: JobReport?
    @State private var isRead = false

    var body: some View {
        Group {
            if let report {
                VStack(alignment: .leading, spacing: 8) {
                    ReportBlocks(report: report)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity)
            } else if isRead {
                Text("The report couldn't be read.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isRead)
        .task {
            report = await jobs.report(of: jobID)
            isRead = true
        }
    }
}
