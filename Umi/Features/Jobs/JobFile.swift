import Foundation

nonisolated struct JobFile: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case document
        case other
    }

    // An exact list, not a type check: a shell script counts as plain text to the system.
    private static let documentExtensions: Set = [
        "txt", "md", "markdown", "csv", "html", "htm", "pdf",
        "png", "jpg", "jpeg", "gif", "heic", "webp", "tif", "tiff"
    ]

    let name: String
    let kind: Kind

    var id: String {
        name
    }

    // The checklist is how Umi follows the job, so it is not one of the files the job made for the user.
    @concurrent
    static func list(in folder: URL) async throws -> [JobFile] {
        try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                                 options: .skipsHiddenFiles)
            .filter { $0.lastPathComponent != JobInstructions.checklistName }
            .map { JobFile(name: $0.lastPathComponent, kind: kind(of: $0)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // Only a plain file with a document's extension opens; a link or a folder is only shown.
    @concurrent
    static func checkedKind(of url: URL) async -> Kind {
        kind(of: url)
    }

    private static func kind(of url: URL) -> Kind {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isRegularFile == true, values?.isSymbolicLink != true,
              documentExtensions.contains(url.pathExtension.lowercased()) else { return .other }
        return .document
    }
}
