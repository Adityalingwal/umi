import SwiftUI

enum SettingsPage: CaseIterable, Identifiable {
    case permissions
    case brain
    case general

    var id: Self { self }

    var title: String {
        switch self {
        case .permissions: "Permissions"
        case .brain: "Brain"
        case .general: "General"
        }
    }

    var line: String {
        switch self {
        case .permissions: "What Umi may use on this Mac."
        case .brain: "Who answers your questions."
        case .general: "Your chat and this copy of Umi."
        }
    }

    var symbol: String {
        switch self {
        case .permissions: "hand.raised.fill"
        case .brain: "sparkles"
        case .general: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .permissions: .blue
        case .brain: .purple
        case .general: .gray
        }
    }
}
