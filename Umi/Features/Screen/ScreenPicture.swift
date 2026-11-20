import Foundation

nonisolated struct ScreenPicture: Sendable {
    let jpegData: Data
    let width: Int
    let height: Int
}
