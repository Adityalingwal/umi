import Foundation

struct ClaudeExecutable {
    let fileManager: FileManager
    // Set only by the Debug launch argument -UmiBrainExecutables.
    let onlyFolder: URL?

    func locate(environment: [String: String]) -> URL? {
        candidates(environment: environment).first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func candidates(environment: [String: String]) -> [URL] {
        if let onlyFolder {
            return [onlyFolder.appending(path: "claude")]
        }
        let home = fileManager.homeDirectoryForCurrentUser
        let usual = [
            home.appending(path: ".local/bin/claude"),
            URL(filePath: "/opt/homebrew/bin/claude"),
            URL(filePath: "/usr/local/bin/claude")
        ]
        let fromPath = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(filePath: String($0)).appending(path: "claude") }
        return usual + fromPath
    }
}
