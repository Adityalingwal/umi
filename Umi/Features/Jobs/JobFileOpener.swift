import AppKit
import OSLog

// A job reads the web and could be led to write a script, so only a document is opened; anything else is only shown.
struct JobFileOpener {
    private static let finderID = "com.apple.finder"

    private let workspace: NSWorkspace
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")

    init(workspace: NSWorkspace) {
        self.workspace = workspace
    }

    // Umi is not the active app, so the system leaves Finder behind unless Finder itself is opened.
    private func bringFinderForward() async {
        guard let finder = workspace.urlForApplication(withBundleIdentifier: Self.finderID) else { return }
        do {
            try await workspace.openApplication(at: finder, configuration: NSWorkspace.OpenConfiguration())
        } catch {
            logger.error("Finder could not be brought forward: \((error as NSError).code, privacy: .public)")
        }
    }

    func open(_ url: URL) async {
        switch await JobFile.checkedKind(of: url) {
        case .document:
            do {
                try await workspace.open(url, configuration: NSWorkspace.OpenConfiguration())
                logger.notice("A job's file is a document: it was opened in the app the Mac uses for it")
            } catch {
                logger.error("A job's file could not be opened: \((error as NSError).code, privacy: .public)")
            }
        case .other:
            workspace.activateFileViewerSelecting([url])
            await bringFinderForward()
            logger.notice("A job's file is not a document: it was only shown in Finder")
        }
    }
}
