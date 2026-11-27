import SwiftUI

// The last finished job's report, in the panel made wider.
struct ReportView: View {
    @Environment(Jobs.self) private var jobs
    @State private var report: JobReport?
    @State private var isRead = false

    var body: some View {
        Group {
            if let report {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ReportBlocks(report: report)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
                .textSelection(.enabled)
            } else if isRead {
                Text("The report couldn't be read.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Read once: a job that starts while the page is open never replaces the report shown.
        .task {
            if let job = jobs.shown {
                report = await jobs.report(of: job.id)
            }
            isRead = true
        }
    }
}
