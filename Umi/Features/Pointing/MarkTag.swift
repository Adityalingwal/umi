nonisolated struct MarkTag {
    enum Name: String, CaseIterable {
        case point
        case box
        case stroke
        case arrow
    }

    let name: Name
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
        return Name.allCases.contains { "<\($0.rawValue)".hasPrefix(lowered) || "</\($0.rawValue)".hasPrefix(lowered) }
            || isTag(lowered)
    }

    static func startsOpening(_ text: some StringProtocol) -> Bool {
        let lowered = text.lowercased()
        return Name.allCases.contains { lowered.hasPrefix("<\($0.rawValue)") }
    }

    static func isClosing(_ tag: String) -> Bool {
        tag.hasPrefix("</")
    }

    static func closes(_ tag: String, named name: Name) -> Bool {
        let lowered = tag.lowercased()
        let closing = "</\(name.rawValue)"
        guard lowered.hasPrefix(closing) else { return false }
        return lowered.dropFirst(closing.count).drop(while: \.isWhitespace) == ">"
    }

    private static func name(after opening: String, in text: some StringProtocol) -> Name? {
        let lowered = text.lowercased()
        return Name.allCases.first { name in
            let start = opening + name.rawValue
            guard lowered.hasPrefix(start), let next = lowered.dropFirst(start.count).first else { return false }
            return next.isWhitespace || next == "/" || next == ">"
        }
    }

    private static func location(named name: Name, in tag: String) -> MarkLocation? {
        switch name {
        case .point:
            guard let values = numbers(["x", "y"], in: tag) else { return nil }
            return .point(PointLocation(pixelX: values[0], pixelY: values[1]))
        case .box:
            guard let values = numbers(["x1", "y1", "x2", "y2"], in: tag) else { return nil }
            return .box(BoxLocation(
                corner: PointLocation(pixelX: values[0], pixelY: values[1]),
                oppositeCorner: PointLocation(pixelX: values[2], pixelY: values[3])
            ))
        case .stroke:
            guard let values = numbers(["x1", "y1", "x2", "y2"], in: tag) else { return nil }
            return .stroke(StrokeLocation(
                start: PointLocation(pixelX: values[0], pixelY: values[1]),
                end: PointLocation(pixelX: values[2], pixelY: values[3])
            ))
        case .arrow:
            guard let values = numbers(["x1", "y1", "x2", "y2"], in: tag) else { return nil }
            return .drag(DragLocation(
                start: PointLocation(pixelX: values[0], pixelY: values[1]),
                end: PointLocation(pixelX: values[2], pixelY: values[3])
            ))
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
