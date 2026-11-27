import Foundation

// The report's Markdown as blocks the panel can draw; what it cannot draw (code, tables) stays plain text.
nonisolated struct JobReport: Sendable {
    enum Block: Sendable {
        case heading(level: Int, text: AttributedString)
        case paragraph(AttributedString)
        case listItem(marker: String, depth: Int, text: AttributedString)
        case quote(AttributedString)
        case plain(String)
        case rule
    }

    private static let webSchemes: Set = ["http", "https"]

    let blocks: [Block]

    @concurrent
    static func read(from url: URL) async throws -> JobReport {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return JobReport(blocks: blocks(in: try AttributedString(markdown: markdown, options: options)))
    }

    private static func blocks(in report: AttributedString) -> [Block] {
        var groups: [(intent: PresentationIntent?, text: AttributedString)] = []
        for run in report.runs {
            let piece = webLinksOnly(AttributedString(report[run.range]))
            if let last = groups.last, sameBlock(last.intent, run.presentationIntent) {
                groups[groups.count - 1].text += piece
            } else {
                groups.append((run.presentationIntent, piece))
            }
        }
        var lastListItem: Int?
        return groups.map { block(for: $0.intent, text: $0.text, lastListItem: &lastListItem) }
    }

    // The cells of a table are one block, so the table becomes one piece of plain text.
    private static func sameBlock(_ first: PresentationIntent?, _ second: PresentationIntent?) -> Bool {
        if let firstTable = table(in: first), let secondTable = table(in: second) {
            return firstTable == secondTable
        }
        return first == second
    }

    private static func table(in intent: PresentationIntent?) -> Int? {
        intent?.components.first { component in
            if case .table = component.kind { return true }
            return false
        }?.identity
    }

    private static func block(
        for intent: PresentationIntent?,
        text: AttributedString,
        lastListItem: inout Int?
    ) -> Block {
        let kinds = intent?.components.map(\.kind) ?? []
        if table(in: intent) != nil {
            return .plain(tableText(text))
        }
        for kind in kinds {
            switch kind {
            case .codeBlock: return .plain(String(text.characters).trimmingCharacters(in: .newlines))
            case .thematicBreak: return .rule
            case .header(let level): return .heading(level: level, text: text)
            case .blockQuote: return .quote(text)
            case .listItem(let ordinal):
                return listItem(ordinal: ordinal, in: intent, kinds: kinds, text: text, lastListItem: &lastListItem)
            default: continue
            }
        }
        return .paragraph(text)
    }

    // A second paragraph in the same item gets no marker of its own.
    private static func listItem(
        ordinal: Int,
        in intent: PresentationIntent?,
        kinds: [PresentationIntent.Kind],
        text: AttributedString,
        lastListItem: inout Int?
    ) -> Block {
        let item = intent?.components.first { if case .listItem = $0.kind { true } else { false } }?.identity
        let isOrdered = kinds.first { $0 == .orderedList || $0 == .unorderedList } == .orderedList
        let depth = kinds.count { $0 == .orderedList || $0 == .unorderedList }
        let marker = item == lastListItem ? "" : (isOrdered ? "\(ordinal)." : "•")
        lastListItem = item
        return .listItem(marker: marker, depth: depth, text: text)
    }

    private static func tableText(_ table: AttributedString) -> String {
        var rows: [String] = []
        var lastRow: Int?
        var lastCell: Int?
        for run in table.runs {
            let components = run.presentationIntent?.components ?? []
            let row = components.compactMap(rowIndex(of:)).first
            let cell = components.first { if case .tableCell = $0.kind { true } else { false } }?.identity
            let text = String(table[run.range].characters)
            if row == lastRow, let last = rows.popLast() {
                rows.append(cell == lastCell ? last + text : last + " | " + text)
            } else {
                rows.append(text)
            }
            lastRow = row
            lastCell = cell
        }
        return rows.joined(separator: "\n")
    }

    private static func rowIndex(of component: PresentationIntent.IntentType) -> Int? {
        switch component.kind {
        case .tableHeaderRow: -1
        case .tableRow(let index): index
        default: nil
        }
    }

    // A link from the web may point at a file or another app, so only a web link stays a link.
    private static func webLinksOnly(_ piece: AttributedString) -> AttributedString {
        var piece = piece
        for run in piece.runs {
            if let link = run.link, !webSchemes.contains(link.scheme?.lowercased() ?? "") {
                piece[run.range].link = nil
            }
            if run.imageURL != nil {
                piece[run.range].imageURL = nil
            }
        }
        return piece
    }
}
