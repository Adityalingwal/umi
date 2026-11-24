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

    var center: CGPoint {
        panel.center
    }

    var isFailed: Bool {
        cursor.state == .failed
    }

    func listen() {
        panel.startFollowingPointer()
        cursor.listen()
    }

    func think() {
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
        if isFailed {
            logger.notice("The fail mark is off")
        }
        cursor.hide()
        panel.stopFollowingPointer()
    }
}
