import Foundation

nonisolated struct CodexFolders: Sendable {
    let home: URL
    let work: URL
    let userLogin: URL

    var catalog: URL { home.appending(path: "catalog.json") }
    var modelsCache: URL { home.appending(path: "models_cache.json") }
    private var login: URL { home.appending(path: "auth.json") }

    init(bundleID: String, environment: [String: String]) {
        home = URL.applicationSupportDirectory.appending(path: bundleID).appending(path: "Codex")
        work = URL.temporaryDirectory.appending(path: "umi-codex")
        let userHome = environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : URL(filePath: $0) }
            ?? URL.homeDirectory.appending(path: ".codex")
        userLogin = userHome.appending(path: "auth.json")
    }

    // Only the link is made or replaced; the user's login file itself is never opened, copied or moved.
    @concurrent
    func prepare() async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: userLogin.path) else {
            throw BrainError.notSignedIn(.codex)
        }
        let linked = try? fileManager.destinationOfSymbolicLink(atPath: login.path)
        guard linked != userLogin.path else { return }
        if linked != nil {
            try fileManager.removeItem(at: login)
        } else if fileManager.fileExists(atPath: login.path) {
            throw BrainError.notSignedIn(.codex)
        }
        try fileManager.createSymbolicLink(at: login, withDestinationURL: userLogin)
    }
}
