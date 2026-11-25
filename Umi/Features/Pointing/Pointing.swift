import AppKit
import OSLog

final class Pointing {
    private enum Phase {
        case waiting
        case travelling
        case resting
        case onLastMark
        case goingHome
        case home
        case over
    }

    private struct WaitingMark {
        let number: Int
        let target: CGPoint
        let label: PointLabel?
    }

    private static let restOnMark = Duration.milliseconds(300)

    private let stage: PointerStage
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let scrolls = ScrollWatch()
    private let clicks = ClickWatch()
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var waitingMarks: [WaitingMark] = []
    private var marksInHand = 0
    private var marksShown = 0
    private var hasTextEnded = false
    private var nextStep: Task<Void, Never>?

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
        case .travelling, .resting, .onLastMark, .goingHome, .home: true
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

    func aim(at location: PointLocation, label: PointLabel?, pictureWidth: Int, pictureHeight: Int) {
        switch phase {
        case .over, .goingHome, .home:
            logger.notice("A location came after pointing had ended, so it is ignored")
            return
        case .waiting, .travelling, .resting, .onLastMark:
            break
        }
        let mapping = ScreenMapping(
            pictureWidth: pictureWidth,
            pictureHeight: pictureHeight,
            displayFrame: displayFrame
        )
        guard let target = mapping.screenPoint(for: location) else {
            logger.notice("A location is outside the screen picture, so its mark is dropped and the others stay")
            return
        }
        marksInHand += 1
        waitingMarks.append(WaitingMark(number: marksInHand, target: target, label: label))
        logger.notice(
            "Mark \(self.marksInHand, privacy: .public) is in hand; a label: \(label != nil, privacy: .public)"
        )
        switch phase {
        case .waiting, .onLastMark:
            flyToNextMark()
        case .travelling, .resting:
            logger.notice("The arrow is busy, so mark \(self.marksInHand, privacy: .public) waits its turn")
        case .goingHome, .home, .over:
            break
        }
    }

    func answerTextEnded() {
        hasTextEnded = true
        if case .onLastMark = phase, marksShown > 1 {
            goHome()
        }
    }

    func answerEnded() {
        switch phase {
        case .travelling, .resting, .onLastMark, .goingHome, .home, .over:
            return
        case .waiting:
            end(because: "the answer ended without a location")
        }
    }

    func stop() {
        end(because: "the question stopped")
    }

    private func flyToNextMark() {
        let mark = waitingMarks.removeFirst()
        let isFirst = marksShown == 0
        let duration = stage.fly(to: mark.target, label: mark.label, startingFrom: cursorRest())
        if isFirst {
            onDepart()
        }
        phase = .travelling
        let time = Self.milliseconds(duration)
        let number = mark.number
        logger.notice("The arrow left for mark \(number, privacy: .public); it lands in \(time, privacy: .public) ms")
        nextStep = after(duration) { $0.land(mark) }
    }

    private func land(_ mark: WaitingMark) {
        guard case .travelling = phase else { return }
        stage.landOnMark(waitingAt: waitingMarks.map(\.target))
        marksShown += 1
        phase = .resting
        logger.notice("The arrow landed and mark \(mark.number, privacy: .public) is on")
        if !clicks.isWatching {
            clicks.start { [weak self] in
                self?.end(because: "the user clicked")
            }
            logger.notice("The click watch started")
        }
        nextStep = after(Self.restOnMark) { $0.leaveMark() }
    }

    private func leaveMark() {
        guard case .resting = phase else { return }
        if !waitingMarks.isEmpty {
            flyToNextMark()
        } else if hasTextEnded, marksShown > 1 {
            goHome()
        } else {
            phase = .onLastMark
        }
    }

    private func goHome() {
        let duration = stage.goHome(to: cursorRest())
        phase = .goingHome
        let time = Self.milliseconds(duration)
        logger.notice("The last mark is visited; the arrow goes home, arriving in \(time, privacy: .public) ms")
        nextStep = after(duration) { $0.arriveHome() }
    }

    private func arriveHome() {
        guard case .goingHome = phase else { return }
        stage.landHome()
        phase = .home
        logger.notice("The arrow is back at its rest by the pointer")
    }

    private func after(_ duration: Duration, then step: @escaping (Pointing) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            step(self)
        }
    }

    private func end(because reason: String) {
        if case .over = phase { return }
        let wasShowing = isShowing
        phase = .over
        nextStep?.cancel()
        waitingMarks = []
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
        logger.notice("Marks shown in this answer: \(self.marksShown, privacy: .public)")
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
