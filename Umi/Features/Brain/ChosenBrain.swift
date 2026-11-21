import Foundation
import OSLog

final class ChosenBrain: Brain {
    private static let choiceKey = "brain"

    private let claude: ClaudeSubscription
    private let codex: CodexSubscription
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private(set) var choice: BrainKind

    init(claude: ClaudeSubscription, codex: CodexSubscription, defaults: UserDefaults) {
        self.claude = claude
        self.codex = codex
        self.defaults = defaults
        choice = defaults.string(forKey: Self.choiceKey).flatMap(BrainKind.init(rawValue:)) ?? .claude
    }

    func prepare() {
        logger.notice("The chosen brain is \(self.choice.title, privacy: .public)")
        prepare(choice)
    }

    func choose(_ brain: BrainKind) {
        guard brain != choice else { return }
        choice = brain
        defaults.set(brain.rawValue, forKey: Self.choiceKey)
        logger.notice("The brain is now \(brain.title, privacy: .public)")
        prepare(brain)
    }

    func stop() {
        claude.stop()
        codex.stop()
    }

    func answer(_ question: BrainQuestion) -> AsyncThrowingStream<String, any Error> {
        logger.notice("Asking \(self.choice.title, privacy: .public)")
        switch choice {
        case .claude: return claude.answer(question)
        case .codex: return codex.answer(question)
        }
    }

    private func prepare(_ brain: BrainKind) {
        switch brain {
        case .claude: claude.prepareIfNeeded()
        case .codex: codex.prepare()
        }
    }
}
