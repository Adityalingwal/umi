import CoreGraphics
import OSLog

final class CursorStage {
    // About two seconds is a guess; the interface pass sets the final time.
    private static let failMarkTime = Duration.seconds(2)

    private let cursor: UmiCursor
    private let panel: CursorPanel
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Turn")
    private var failMarkHiding: Task<Void, Never>?

    init(cursor: UmiCursor, panel: CursorPanel) {
        self.cursor = cursor
        self.panel = panel
    }

    var restBesidePointer: CGPoint {
        panel.restBesidePointer
    }

    var isFailed: Bool {
        cursor.state == .failed
    }

    func listen() {
        panel.startFollowingPointer()
        cursor.listen()
    }

    func think() {
        panel.startFollowingPointer()
        cursor.think()
    }

    func fail() {
        hide()
        panel.startFollowingPointer()
        cursor.fail()
        logger.notice("The fail mark is on")
        failMarkHiding = Task { [weak self] in
            try? await Task.sleep(for: Self.failMarkTime)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        failMarkHiding?.cancel()
        failMarkHiding = nil
        switch cursor.state {
        case .thinking: logger.notice("The thinking cursor is off")
        case .failed: logger.notice("The fail mark is off")
        case .hidden, .listening: break
        }
        cursor.hide()
        panel.stopFollowingPointer()
    }
}
