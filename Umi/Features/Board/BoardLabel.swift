import AppKit
import SwiftUI

enum BoardLabel {
    enum Style {
        case box
        case region
        case text
        case note
        case connector

        var size: Double {
            switch self {
            case .box, .text: 14
            case .region: 12.5
            case .note, .connector: 12
            }
        }

        var weight: Font.Weight {
            switch self {
            case .box, .note: .medium
            case .region: .semibold
            case .text, .connector: .regular
            }
        }

        fileprivate var appKitWeight: NSFont.Weight {
            switch self {
            case .box, .note: .medium
            case .region: .semibold
            case .text, .connector: .regular
            }
        }
    }

    static let longest = 60

    static func font(_ style: Style) -> Font {
        .system(size: style.size, weight: style.weight, design: .rounded)
    }

    static func size(of label: String, style: Style, maxWidth: Double) -> CGSize {
        let base = NSFont.systemFont(ofSize: style.size, weight: style.appKitWeight)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: style.size) } ?? base
        let bounds = NSAttributedString(string: label, attributes: [.font: font]).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(width: ceil(bounds.width) + 2, height: ceil(bounds.height) + 2)
    }

    static func trimmed(_ label: String?) -> String? {
        guard let text = label?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return String(text.prefix(longest))
    }
}
