import SwiftUI

// Shown under the notch by itself when a job ends; it never takes the keyboard.
struct JobBanner: View {
    let job: Job
    let notchHeight: CGFloat
    let showReport: () -> Void

    var body: some View {
        if let outcome = JobOutcome(job.state) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(outcome.title, systemImage: outcome.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(outcome.tint)
                        .fixedSize()
                    Text(job.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if outcome.hasReport {
                        FullReportButton(show: showReport)
                    }
                }
                Text(outcome.line)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, NotchPlace.shoulder + 14)
            .padding(.top, notchHeight + 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(job.name): \(outcome.title)")
        }
    }
}
