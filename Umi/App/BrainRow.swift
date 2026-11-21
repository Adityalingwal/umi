import AppKit
import OSLog

final class BrainRow: NSObject {
    let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    private let brain: ChosenBrain
    private let check: BrainCheck
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Brain")
    private var availability: [BrainKind: BrainAvailability] = [:]
    private var refresh: Task<Void, Never>?

    init(brain: ChosenBrain, check: BrainCheck) {
        self.brain = brain
        self.check = check
        super.init()
        item.submenu = makeSubmenu()
    }

    func menuNeedsUpdate() {
        show()
        refreshAvailability()
    }

    private func makeSubmenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for kind in BrainKind.allCases {
            let item = NSMenuItem(title: kind.title, action: #selector(brainItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = kind.rawValue
            menu.addItem(item)
        }
        return menu
    }

    private func refreshAvailability() {
        refresh?.cancel()
        refresh = Task { [weak self] in
            guard let self else { return }
            async let claude = check.availability(of: .claude)
            async let codex = check.availability(of: .codex)
            let found = await [BrainKind.claude: claude, .codex: codex].compactMapValues { $0 }
            guard !Task.isCancelled else { return }
            availability.merge(found) { _, new in new }
            show()
            logShownOptions()
        }
    }

    private func show() {
        item.title = "Brain: \(brain.choice.title)"
        for option in item.submenu?.items ?? [] {
            guard let kind = Self.kind(of: option) else { continue }
            let found = availability[kind]
            option.state = kind == brain.choice ? .on : .off
            option.isEnabled = found.map { $0 == .usable } ?? true
            option.subtitle = found.flatMap { $0.hint(for: kind) }
        }
    }

    private func logShownOptions() {
        for option in item.submenu?.items ?? [] {
            let title = option.title
            let isChosen = option.state == .on
            let isEnabled = option.isEnabled
            let hint = option.subtitle ?? "none"
            logger.notice("Brain option \(title, privacy: .public): chosen \(isChosen, privacy: .public)")
            logger.notice("Brain option \(title, privacy: .public): enabled \(isEnabled, privacy: .public)")
            logger.notice("Brain option \(title, privacy: .public): hint \(hint, privacy: .public)")
        }
    }

    private static func kind(of option: NSMenuItem) -> BrainKind? {
        (option.representedObject as? String).flatMap(BrainKind.init(rawValue:))
    }

    @objc private func brainItemClicked(_ option: NSMenuItem) {
        guard let kind = Self.kind(of: option) else { return }
        brain.choose(kind)
        show()
    }
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
        case (.notSignedIn(.loginNotInFile), .codex):
            "Keep the login in a file: run codex -c cli_auth_credentials_store=file login"
        }
    }
}
