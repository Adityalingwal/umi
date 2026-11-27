import Foundation

nonisolated struct JobStep: Equatable, Sendable {
    let text: String
    let isDone: Bool

    // A checklist is lines like "- [ ] step" and "- [x] step"; any other line is not a step.
    static func steps(inChecklist text: String) -> [JobStep] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let line = line.trimmingCharacters(in: .whitespaces)
            guard let match = line.wholeMatch(of: /[-*]\s*\[([ xX])\]\s*(.+)/) else { return nil }
            let step = String(match.output.2).trimmingCharacters(in: .whitespaces)
            return step.isEmpty ? nil : JobStep(text: step, isDone: match.output.1 != " ")
        }
    }
}
