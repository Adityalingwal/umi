import Foundation

struct BrainParts {
    private let environment: [String: String]
    private let claudeExecutable: ClaudeExecutable
    private let codexExecutable: CodexExecutable
    private let codexFolders: CodexFolders

    init(environment: [String: String], defaults: UserDefaults) {
        self.environment = environment
        let onlyFolder = Self.executablesFolder(defaults: defaults)
        claudeExecutable = ClaudeExecutable(fileManager: .default, onlyFolder: onlyFolder)
        codexExecutable = CodexExecutable(fileManager: .default, onlyFolder: onlyFolder)
        codexFolders = CodexFolders(bundleID: Bundle.main.bundleIdentifier ?? "Umi", environment: environment)
    }

    func makeChosenBrain(defaults: UserDefaults) -> ChosenBrain {
        ChosenBrain(
            claude: ClaudeSubscription(executable: claudeExecutable, environment: environment),
            codex: CodexSubscription(executable: codexExecutable, folders: codexFolders, environment: environment),
            defaults: defaults
        )
    }

    func makeCheck() -> BrainCheck {
        BrainCheck(
            claudeExecutable: claudeExecutable,
            codexExecutable: codexExecutable,
            codexFolders: codexFolders,
            environment: environment
        )
    }

    func makeJobs(folder: URL) -> Jobs {
        Jobs(runner: ClaudeJobRunner(
            executable: claudeExecutable,
            environment: environment,
            jobsFolder: folder
        ))
    }

    private static func executablesFolder(defaults: UserDefaults) -> URL? {
        #if DEBUG
        defaults.string(forKey: "UmiBrainExecutables").map { URL(filePath: $0) }
        #else
        nil
        #endif
    }
}
