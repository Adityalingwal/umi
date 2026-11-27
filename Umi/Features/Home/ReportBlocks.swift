import SwiftUI

// A report's blocks in order, for the panel's report and a job's page in the window.
struct ReportBlocks: View {
    let report: JobReport

    var body: some View {
        ForEach(Array(report.blocks.enumerated()), id: \.offset) { _, block in
            ReportBlockView(block: block)
        }
    }
}
