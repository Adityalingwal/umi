import AppKit
import OSLog

// A job reads the web and could be led to write a script, so only a document is opened; anything else is only shown.
struct JobFileOpener {
    private let workspace: NSWorkspace
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Jobs")

    init(workspace: NSWorkspace) {
        self.workspace = workspace
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
            logger.notice("A job's file is not a document: it was only shown in Finder")
        }
    }
}
