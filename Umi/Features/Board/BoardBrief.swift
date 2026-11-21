import Foundation
import OSLog

enum BoardBrief {
    static func text(unfinished: Drawing?, lastComplete: Drawing?, isShown: Bool) -> String? {
        do {
            if let unfinished {
                return try stoppedText(unfinished, lastComplete: lastComplete, isShown: isShown)
            }
            return try lastComplete.map { try currentText($0, isShown: isShown) }
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Board")
                .error("The board could not be described for the brain: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func currentText(_ drawing: Drawing, isShown: Bool) throws -> String {
        let place = isShown ? "The board shows it now." : "The user closed the board; the diagram is still kept."
        return [
            "The board: the current diagram is \"\(drawing.title)\". \(place) An edit changes this diagram. "
                + "Its marks, one per line:",
            try marks(of: drawing)
        ].joined(separator: "\n")
    }

    private static func stoppedText(_ drawing: Drawing, lastComplete: Drawing?, isShown: Bool) throws -> String {
        let complete = lastComplete.map { last in
            isShown
                ? "The last complete diagram, \"\(last.title)\", is back on the board."
                : "The last complete diagram, \"\(last.title)\", is kept; the board is closed."
        } ?? "There is no complete diagram, so the board closed."
        return [
            "The board: this question stopped a diagram while it was being drawn, \"\(drawing.title)\". "
                + "An edit changes this diagram. Its marks drawn so far, one per line:",
            try marks(of: drawing),
            complete
        ].joined(separator: "\n")
    }

    private static func marks(of drawing: Drawing) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let lines = try drawing.marks.map { mark in
            guard let line = String(bytes: try encoder.encode(mark.asPlaced), encoding: .utf8) else {
                throw DrawingError.badMark
            }
            return line
        }
        return lines.isEmpty ? "(no marks yet)" : lines.joined(separator: "\n")
    }
}
