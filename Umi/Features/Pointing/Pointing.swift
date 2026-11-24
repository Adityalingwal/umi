import AppKit
import OSLog

final class Pointing {
    private enum Phase {
        case waiting
        case aimed(CGPoint)
        case travelling
        case landed
        case marked
        case over
    }

    private enum Cue {
        case nameAwaited
        case nameSpoken
    }

    private static let clearAfterLine = Duration.seconds(1)

    private let stage: PointerStage
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let scrolls = ScrollWatch()
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var cue = Cue.nameAwaited
    private var departing: Task<Void, Never>?
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
        case .travelling, .landed, .marked: true
        case .waiting, .aimed, .over: false
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

    func aim(at location: PointLocation, pictureWidth: Int, pictureHeight: Int, opensAnswer: Bool) -> Bool {
        guard case .waiting = phase else {
            logger.notice("A location came after pointing had ended, so it is ignored")
            return false
        }
        let mapping = ScreenMapping(
            pictureWidth: pictureWidth,
            pictureHeight: pictureHeight,
            displayFrame: displayFrame
        )
        guard let target = mapping.screenPoint(for: location) else {
            end(because: "the location is outside the screen picture")
            return false
        }
        phase = .aimed(target)
        logger.notice("The location is in hand; the name opens the answer: \(opensAnswer, privacy: .public)")
        if opensAnswer {
            depart(taking: stage.usualTravelTime(from: cursorRest(), to: target))
        }
        return true
    }

    func nameComing(after delay: Duration) {
        guard case .aimed(let target) = phase, departing == nil else { return }
        let travelTime = stage.usualTravelTime(from: cursorRest(), to: target)
        let wait = delay - travelTime
        logger.notice(
            """
            The name plays in \(Self.milliseconds(delay), privacy: .public) ms; \
            the cursor leaves in \(Self.milliseconds(max(.zero, wait)), privacy: .public) ms
            """
        )
        guard wait > .zero else {
            depart(taking: max(Travel.shortestDuration, delay))
            return
        }
        departing = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self?.depart(taking: travelTime)
        }
    }

    func nameStarted() {
        guard cue == .nameAwaited else { return }
        logger.notice("The name started playing")
        cue = .nameSpoken
        switch phase {
        case .aimed:
            logger.notice("The name started before the cursor left, so it leaves now")
            departing?.cancel()
            depart(taking: Travel.shortestDuration)
        case .landed:
            showMark()
        case .waiting, .travelling, .marked, .over:
            return
        }
    }

    func nameLineEnded() {
        switch phase {
        case .marked:
            clearLater()
        case .aimed, .travelling, .landed:
            end(because: "the line ended before the mark could show")
        case .waiting, .over:
            return
        }
    }

    func answerEnded() {
        switch phase {
        case .over:
            return
        case .marked:
            if clearing == nil {
                clearLater()
            }
        case .waiting, .aimed, .travelling, .landed:
            end(because: "the answer ended before the name")
        }
    }

    func stop() {
        end(because: "the question stopped")
    }

    private func depart(taking duration: Duration) {
        guard case .aimed(let target) = phase else { return }
        departing = nil
        stage.travel(from: cursorRest(), to: target, taking: duration)
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
        phase = .landed
        logger.notice("The cursor landed")
        if cue == .nameSpoken {
            showMark()
        }
    }

    private func showMark() {
        stage.mark()
        phase = .marked
        logger.notice("The mark is on")
    }

    private func clearLater() {
        clearing = Task { [weak self] in
            try? await Task.sleep(for: Self.clearAfterLine)
            guard !Task.isCancelled else { return }
            self?.end(because: "one second passed after its line", fading: true)
        }
    }

    private func end(because reason: String, fading: Bool = false) {
        if case .over = phase { return }
        let wasShowing = isShowing
        phase = .over
        departing?.cancel()
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
