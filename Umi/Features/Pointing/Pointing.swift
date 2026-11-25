import AppKit
import OSLog

final class Pointing {
    private enum Phase {
        case waiting
        case travelling
        case resting
        case onLastMark
        case arrowHidden
        case goingHome
        case home
        case over
    }

    private static let restOnMark = Duration.milliseconds(300)
    // A flight after the arrow hid starts beside the pointer where the click was; its length must not tell how far.
    private static let flightAfterHiding = Duration.milliseconds(500)

    private let stage: PointerStage
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let scrolls = ScrollWatch()
    private let clicks = ClickWatch()
    private let pointerMoves = PointerMoveWatch()
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var waitingMarks: [AnswerMark] = []
    private var marksOnScreen: [AnswerMark] = []
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
        case .travelling, .resting, .onLastMark, .arrowHidden, .goingHome, .home: true
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

    func aim(at location: MarkLocation, label: PointLabel?, pictureWidth: Int, pictureHeight: Int) {
        switch phase {
        case .over, .goingHome, .home:
            logger.notice("A location came after pointing had ended, so it is ignored")
            return
        case .waiting, .travelling, .resting, .onLastMark, .arrowHidden:
            break
        }
        let mapping = ScreenMapping(
            pictureWidth: pictureWidth,
            pictureHeight: pictureHeight,
            displayFrame: displayFrame
        )
        guard let place = mapping.screenPlace(for: location) else {
            logger.notice("A location is outside the screen picture, so its mark is dropped and the others stay")
            return
        }
        marksInHand += 1
        waitingMarks.append(AnswerMark(number: marksInHand, place: place, label: label))
        let number = marksInHand
        logger.notice("Mark \(number, privacy: .public) is in hand: \(place.kindName, privacy: .public)")
        logger.notice("Mark \(number, privacy: .public) has a label: \(label != nil, privacy: .public)")
        switch phase {
        case .waiting, .onLastMark, .arrowHidden:
            flyToNextMark()
        case .travelling, .resting:
            logger.notice("The arrow is busy, so mark \(number, privacy: .public) waits its turn")
        case .goingHome, .home, .over:
            break
        }
    }

    func answerTextEnded() {
        hasTextEnded = true
        endIfAnswerIsDone()
        if [.onLastMark, .arrowHidden].contains(phase), marksShown > 1 {
            goHome()
        }
    }

    func answerEnded() {
        switch phase {
        case .travelling, .resting, .onLastMark, .arrowHidden, .goingHome, .home, .over:
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
        let fixed = phase == .arrowHidden ? Self.flightAfterHiding : nil
        let duration = stage.fly(to: mark.place, startingFrom: cursorRest(), taking: fixed)
        if isFirst {
            onDepart()
        }
        phase = .travelling
        let time = Self.milliseconds(duration)
        let number = mark.number
        logger.notice("The arrow left for mark \(number, privacy: .public); it lands in \(time, privacy: .public) ms")
        nextStep = after(duration) { $0.land(mark) }
    }

    private func land(_ mark: AnswerMark) {
        guard case .travelling = phase else { return }
        stage.landOnMark(numbered: mark.number, at: mark.place, label: mark.label, waitingAt: waitingMarks.map(\.place))
        marksOnScreen.append(mark)
        marksShown += 1
        phase = .resting
        logger.notice("The arrow landed and mark \(mark.number, privacy: .public) is on")
        if !clicks.isWatching {
            clicks.start { [weak self] press in
                self?.clicked(at: press)
            }
            logger.notice("The click watch started")
        }
        nextStep = after(Self.restOnMark) { $0.leaveMark() }
    }

    private func clicked(at press: CGPoint) {
        guard !marksOnScreen.isEmpty else { return }
        let cleared = marksOnScreen.filter { $0.isUnder(press) }
        guard !cleared.isEmpty else {
            logger.notice("A click landed elsewhere")
            end(because: "the user clicked elsewhere")
            return
        }
        clear(cleared)
    }

    private func clear(_ cleared: [AnswerMark]) {
        let numbers = cleared.map(\.number)
        marksOnScreen.removeAll { numbers.contains($0.number) }
        stage.clearMarks(numbered: numbers)
        let gone = cleared.count
        let left = marksOnScreen.count
        logger.notice("A click landed on a mark; cleared: \(gone, privacy: .public), left: \(left, privacy: .public)")
        if numbers.contains(marksShown) {
            hideArrowBesideClearedMark()
        }
        guard marksOnScreen.isEmpty else { return }
        stopClickWatch()
        endIfAnswerIsDone()
    }

    private func hideArrowBesideClearedMark() {
        switch phase {
        case .resting, .onLastMark:
            break
        case .waiting, .travelling, .arrowHidden, .goingHome, .home, .over:
            return
        }
        nextStep?.cancel()
        stage.hideArrow()
        phase = .arrowHidden
        logger.notice("The mark beside the arrow was cleared, so the arrow hides")
        if !waitingMarks.isEmpty {
            flyToNextMark()
        } else if hasTextEnded, marksShown > 1, !marksOnScreen.isEmpty {
            goHome()
        }
    }

    private func endIfAnswerIsDone() {
        guard hasTextEnded, marksOnScreen.isEmpty, waitingMarks.isEmpty else { return }
        switch phase {
        case .resting, .onLastMark, .arrowHidden, .goingHome, .home:
            end(because: "the last mark was cleared and the answer's text has ended")
        case .waiting, .travelling, .over:
            break
        }
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
        guard duration > .zero else { return arriveHome() }
        nextStep = after(duration) { $0.arriveHome() }
    }

    private func arriveHome() {
        guard case .goingHome = phase else { return }
        stage.landHome()
        phase = .home
        keepHomeBesidePointer()
        pointerMoves.start { [weak self] in
            self?.keepHomeBesidePointer()
        }
        logger.notice("The arrow is back at its rest by the pointer and follows it")
    }

    private func keepHomeBesidePointer() {
        guard case .home = phase else { return }
        stage.keepHome(at: cursorRest())
    }

    private func after(_ duration: Duration, then step: @escaping (Pointing) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            step(self)
        }
    }

    private func stopClickWatch() {
        guard clicks.isWatching else { return }
        clicks.stop()
        logger.notice("The click watch stopped")
    }

    private func end(because reason: String) {
        if case .over = phase { return }
        let wasShowing = isShowing
        phase = .over
        nextStep?.cancel()
        waitingMarks = []
        marksOnScreen = []
        appSwitches.stop()
        scrolls.stop()
        pointerMoves.stop()
        stopClickWatch()
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
