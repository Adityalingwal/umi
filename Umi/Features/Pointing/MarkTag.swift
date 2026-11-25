nonisolated struct MarkTag {
    private static let names = ["point"]

    let name: String
    let location: MarkLocation
    let label: PointLabel?

    init?(_ tag: String) {
        guard let name = Self.name(after: "<", in: tag) else { return nil }
        let label = tag.firstMatch(of: /\blabel\s*=\s*(?:"([^"]*)"|'([^']*)'|["'].*|([^\s"'<>\/]*))/.ignoresCase())
        var place = tag
        if let label {
            place.removeSubrange(label.range)
        }
        guard let location = Self.location(named: name, in: place) else { return nil }
        let written = label.flatMap { $0.output.1 ?? $0.output.2 ?? $0.output.3 }
        self.name = name
        self.location = location
        self.label = written.flatMap { PointLabel(String($0)) }
    }

    static func opens(_ text: some StringProtocol) -> Bool {
        name(after: "<", in: text) != nil
    }

    static func isTag(_ text: some StringProtocol) -> Bool {
        opens(text) || name(after: "</", in: text) != nil
    }

    static func mayBecomeTag(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return names.contains { "<\($0)".hasPrefix(lowered) || "</\($0)".hasPrefix(lowered) } || isTag(lowered)
    }

    static func startsOpening(_ text: some StringProtocol) -> Bool {
        let lowered = text.lowercased()
        return names.contains { lowered.hasPrefix("<\($0)") }
    }

    static func isClosing(_ tag: String) -> Bool {
        tag.hasPrefix("</")
    }

    static func closes(_ tag: String, named name: String) -> Bool {
        let lowered = tag.lowercased()
        guard lowered.hasPrefix("</\(name)") else { return false }
        return lowered.dropFirst(name.count + 2).drop(while: \.isWhitespace) == ">"
    }

    private static func name(after opening: String, in text: some StringProtocol) -> String? {
        let lowered = text.lowercased()
        return names.first { name in
            guard lowered.hasPrefix(opening + name), let next = lowered.dropFirst(opening.count + name.count).first
            else { return false }
            return next.isWhitespace || next == "/" || next == ">"
        }
    }

    private static func location(named name: String, in tag: String) -> MarkLocation? {
        switch name {
        case "point":
            guard let values = numbers(["x", "y"], in: tag) else { return nil }
            return .point(PointLocation(pixelX: values[0], pixelY: values[1]))
        default:
            return nil
        }
    }

    private static func numbers(_ keys: [String], in tag: String) -> [Double]? {
        var found: [String: Double] = [:]
        for match in tag.lowercased().matches(of: /\b([xy][12]?)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>\/]*))/) {
            let key = String(match.output.1)
            guard keys.contains(key) else { continue }
            let text = match.output.2 ?? match.output.3 ?? match.output.4 ?? ""
            guard found[key] == nil, let value = coordinate(in: text) else { return nil }
            found[key] = value
        }
        let values = keys.compactMap { found[$0] }
        return values.count == keys.count ? values : nil
    }

    private static func coordinate(in text: Substring) -> Double? {
        guard let match = text.wholeMatch(of: /\s*(-?[0-9]+(?:\.[0-9]+)?)\s*/) else { return nil }
        return Double(match.output.1)
    }
}
