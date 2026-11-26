import Foundation
import Observation
import OSLog

@Observable
final class BrainOptions {
    private(set) var choice: BrainKind
    private var availability: [BrainKind: BrainAvailability] = [:]

    @ObservationIgnored private let brain: ChosenBrain
    @ObservationIgnored private let check: BrainCheck
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    @ObservationIgnored private var refreshes: [BrainKind: Task<Void, Never>] = [:]

    init(brain: ChosenBrain, check: BrainCheck) {
        self.brain = brain
        self.check = check
        choice = brain.choice
    }

    // Until its check answers, a brain can be picked.
    func isEnabled(_ kind: BrainKind) -> Bool {
        availability[kind].map { $0 == .usable } ?? true
    }

    func hint(for kind: BrainKind) -> String? {
        availability[kind].flatMap { $0.hint(for: kind) }
    }

    func refresh() {
        choice = brain.choice
        for kind in BrainKind.allCases {
            refreshes[kind]?.cancel()
            refreshes[kind] = Task { [weak self] in
                guard let self else { return }
                let found = await check.availability(of: kind)
                guard let found, !Task.isCancelled else { return }
                availability[kind] = found
                #if DEBUG
                logShownOptions()
                #endif
            }
        }
    }

    func choose(_ kind: BrainKind) {
        guard isEnabled(kind) else { return }
        brain.choose(kind)
        choice = brain.choice
    }

    #if DEBUG
    private func logShownOptions() {
        for kind in BrainKind.allCases {
            let title = kind.title
            let isChosen = kind == choice
            let isEnabled = isEnabled(kind)
            let hint = hint(for: kind) ?? "none"
            logger.notice("Brain option \(title, privacy: .public): chosen \(isChosen, privacy: .public)")
            logger.notice("Brain option \(title, privacy: .public): enabled \(isEnabled, privacy: .public)")
            logger.notice("Brain option \(title, privacy: .public): hint \(hint, privacy: .public)")
        }
    }
    #endif
}

private extension BrainAvailability {
    func hint(for brain: BrainKind) -> String? {
        switch (self, brain) {
        case (.usable, _): nil
        case (.notInstalled, .claude): "Install Claude Code"
        case (.notInstalled, .codex): "Install Codex"
        case (.notSignedIn, .claude): "Sign in: run claude auth login in Terminal"
        case (.notSignedIn(.noLogin), .codex): "Sign in: run codex login in Terminal"
        case (.notSignedIn(.notChatGPT), .codex): "Sign in with ChatGPT: run codex login in Terminal"
        }
    }
}
