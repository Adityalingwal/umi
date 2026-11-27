import SwiftUI

// The window's left column: the user's chat, then this run's jobs under "Recents", newest first.
struct WindowColumn: View {
    static let width = 200.0

    @Environment(Notch.self) private var notch
    @Environment(Jobs.self) private var jobs

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ColumnRow(isSelected: notch.windowContent == .chat, help: nil, select: notch.showChatInWindow) {
                Label("Chat", systemImage: "bubble.left.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .accessibilityLabel("Chat")
            Text("Recents")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
            if jobs.all.isEmpty {
                Text("No jobs yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .transition(.opacity)
            } else {
                JobRows(jobs: jobs.all, selected: notch.windowContent, select: notch.showJobInWindow)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.white.opacity(0.04))
        .animation(.easeOut(duration: 0.2), value: jobs.all.map(\.id))
    }
}

private struct JobRows: View {
    let jobs: [Job]
    let selected: HomeContent
    let select: (UUID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(jobs) { job in
                    ColumnRow(isSelected: selected == .job(job.id), help: job.name) {
                        select(job.id)
                    } content: {
                        JobRowLabel(job: job)
                    }
                    .accessibilityLabel(job.name)
                    .accessibilityValue(JobRowLabel.word(for: job.state))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .scrollIndicators(.never)
    }
}

private struct JobRowLabel: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(job.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(Self.word(for: job.state))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Self.tint(for: job.state))
                .contentTransition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: Self.word(for: job.state))
    }

    static func word(for state: Job.State) -> String {
        switch state {
        case .working: "working"
        case .done: "done"
        case .stopped: "stopped"
        case .failed: "did not finish"
        }
    }

    private static func tint(for state: Job.State) -> Color {
        switch state {
        case .working: .green.opacity(0.9)
        case .done, .stopped: .white.opacity(0.45)
        case .failed: .orange.opacity(0.9)
        }
    }
}

// A row of the column: the whole row is the click target, lit on hover and more when it is the page shown.
private struct ColumnRow<Content: View>: View {
    let isSelected: Bool
    let help: String?
    let select: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    .white.opacity(isSelected ? 0.12 : (isHovered ? 0.06 : 0)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .help(help ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
