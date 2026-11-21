import Foundation

struct CodexExecutable {
    let fileManager: FileManager

    func locate(environment: [String: String]) -> URL? {
        candidates(environment: environment).first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func candidates(environment: [String: String]) -> [URL] {
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
