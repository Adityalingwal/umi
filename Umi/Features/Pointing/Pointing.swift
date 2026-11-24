import AppKit
import OSLog

final class Pointing {
    private enum Phase {
        case waiting
        case travelling
        case marked
        case over
    }

    private let stage: PointerStage
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let scrolls = ScrollWatch()
    private let clicks = ClickWatch()
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var landing: Task<Void, Never>?

    init(
        stage: PointerStage,
        displayFrame: CGRect,
        workspace: NSWorkspace,
        cursorRest: @escaping () -> CGPoint,
        onDepart: @escaping () -> Void
    ) {
        self.stage = stage
        self.displayFrame = displayFrame
        appSwitches = AppSwitchWatch(workspace: workspace)
        self.cursorRest = cursorRest
        self.onDepart = onDepart
    }

    var isShowing: Bool {
        switch phase {
        case .travelling, .marked: true
        case .waiting, .over: false
        }
    }

    func start(capturedApp: pid_t?) {
        appSwitches.start(capturedApp: capturedApp) { [weak self] in
            self?.end(because: "another app became active")
        }
        scrolls.start { [weak self] in
            self?.end(because: "a scroll moved the screen")
        }
    }

    func aim(at location: PointLocation, pictureWidth: Int, pictureHeight: Int) {
        guard case .waiting = phase else {
            logger.notice("A location came after pointing had ended, so it is ignored")
            return
        }
        let mapping = ScreenMapping(
            pictureWidth: pictureWidth,
            pictureHeight: pictureHeight,
            displayFrame: displayFrame
        )
        guard let target = mapping.screenPoint(for: location) else {
            end(because: "the location is outside the screen picture")
            return
        }
        logger.notice("The location is in hand, so the cursor leaves now")
        depart(to: target)
    }

    func answerEnded() {
        switch phase {
        case .travelling, .marked, .over:
            return
        case .waiting:
            end(because: "the answer ended without a location")
        }
    }

    func stop() {
        end(because: "the question stopped")
    }

    private func depart(to target: CGPoint) {
        let rest = cursorRest()
        let duration = stage.usualTravelTime(from: rest, to: target)
        stage.travel(from: rest, to: target, taking: duration)
        onDepart()
        phase = .travelling
        logger.notice("The cursor left; it lands in \(Self.milliseconds(duration), privacy: .public) ms")
        landing = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.land()
        }
    }

    private func land() {
        guard case .travelling = phase else { return }
        stage.land()
        phase = .marked
        clicks.start { [weak self] in
            self?.end(because: "the user clicked")
        }
        logger.notice("The cursor landed and the mark is on; the click watch started")
    }

    private func end(because reason: String) {
        if case .over = phase { return }
        let wasShowing = isShowing
        phase = .over
        landing?.cancel()
        appSwitches.stop()
        scrolls.stop()
        if clicks.isWatching {
            clicks.stop()
            logger.notice("The click watch stopped")
        }
        if wasShowing {
            stage.clear()
        }
        logger.notice("Pointing ended: \(reason, privacy: .public); it was showing: \(wasShowing, privacy: .public)")
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
