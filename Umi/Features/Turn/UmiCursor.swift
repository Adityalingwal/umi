import Foundation
import Observation

@Observable
final class UmiCursor {
    private static let levelFall = 0.85

    private(set) var state = CursorState.hidden
    private(set) var level = 0.0

    func listen() {
        level = 0
        state = .listening
    }

    func hear(_ newLevel: AudioLevel) {
        guard state == .listening else { return }
        level = max(newLevel.fraction, level * Self.levelFall)
    }

    func think() {
        state = .thinking
    }

    func fail() {
        state = .failed
    }

    func hide() {
        state = .hidden
    }
}
