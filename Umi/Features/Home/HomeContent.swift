import Foundation

// What the window shows beside its left column.
enum HomeContent: Equatable {
    case chat
    case job(UUID)
    case settings
}
