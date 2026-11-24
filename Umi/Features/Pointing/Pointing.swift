import AppKit
import OSLog

final class Pointing {
    private enum Phase {
        case waiting
        case travelling(isAnswerOver: Bool)
        case marked
        case over
    }

    private static let clearAfterAnswer = Duration.seconds(1)

    private let stage: PointerStage
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let scrolls = ScrollWatch()
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var landing: Task<Void, Never>?
    private var clearing: Task<Void, Never>?

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
        case .over:
            return
        case .travelling:
            phase = .travelling(isAnswerOver: true)
            logger.notice("The answer ended before the cursor landed")
        case .marked:
            clearLater()
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
        phase = .travelling(isAnswerOver: false)
        logger.notice("The cursor left; it lands in \(Self.milliseconds(duration), privacy: .public) ms")
        landing = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.land()
        }
    }

    private func land() {
        guard case .travelling(let isAnswerOver) = phase else { return }
        stage.land()
        phase = .marked
        logger.notice("The cursor landed and the mark is on")
        if isAnswerOver {
            clearLater()
        }
    }

    private func clearLater() {
        clearing = Task { [weak self] in
            try? await Task.sleep(for: Self.clearAfterAnswer)
            guard !Task.isCancelled else { return }
            self?.end(because: "one second passed after the answer", fading: true)
        }
    }

    private func end(because reason: String, fading: Bool = false) {
        if case .over = phase { return }
        let wasShowing = isShowing
        phase = .over
        landing?.cancel()
        clearing?.cancel()
        appSwitches.stop()
        scrolls.stop()
        if wasShowing {
            stage.clear(fading: fading)
        }
        logger.notice("Pointing ended: \(reason, privacy: .public); it was showing: \(wasShowing, privacy: .public)")
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
