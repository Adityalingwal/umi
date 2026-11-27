import SwiftUI

// One step of a job's checklist: done steps struck through, the current one bold.
struct JobStepRow: View {
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
