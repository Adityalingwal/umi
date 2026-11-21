import Foundation

struct CodexExecutable {
    let fileManager: FileManager
    // Set only by the Debug launch argument -UmiBrainExecutables.
    let onlyFolder: URL?

    func locate(environment: [String: String]) -> URL? {
        candidates(environment: environment).first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func candidates(environment: [String: String]) -> [URL] {
        if let onlyFolder {
            return [onlyFolder.appending(path: "codex")]
        }
        let home = fileManager.homeDirectoryForCurrentUser
        let usual = [
            home.appending(path: ".local/bin/codex"),
            URL(filePath: "/opt/homebrew/bin/codex"),
            URL(filePath: "/usr/local/bin/codex")
        ]
        let fromPath = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(filePath: String($0)).appending(path: "codex") }
        return usual + fromPath
    }
}
