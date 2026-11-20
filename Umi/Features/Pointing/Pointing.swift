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

    private static let clearAfterLine = Duration.seconds(2)
    private static let fadeOut = Duration.milliseconds(200)

    private let panel: PointerPanel
    private let overlay: PointerOverlay
    private let displayFrame: CGRect
    private let appSwitches: AppSwitchWatch
    private let cursorRest: () -> CGPoint
    private let onDepart: () -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Pointing")
    private var phase = Phase.waiting
    private var isNameStarted = false
    private var departing: Task<Void, Never>?
    private var landing: Task<Void, Never>?
    private var clearing: Task<Void, Never>?
    private var hiding: Task<Void, Never>?

    init(
        panel: PointerPanel,
        overlay: PointerOverlay,
        displayFrame: CGRect,
        workspace: NSWorkspace,
        cursorRest: @escaping () -> CGPoint,
        onDepart: @escaping () -> Void
    ) {
        self.panel = panel
        self.overlay = overlay
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
            depart(taking: Travel.usualDuration(from: viewPoint(cursorRest()), to: viewPoint(target)))
        }
        return true
    }

    func nameComing(after delay: Duration) {
        guard case .aimed(let target) = phase, departing == nil else { return }
        let travelTime = Travel.usualDuration(from: viewPoint(cursorRest()), to: viewPoint(target))
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
        logger.notice("The name started playing")
        isNameStarted = true
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

    func voiceEnded() {
        switch phase {
        case .marked:
            if clearing == nil {
                clearLater()
            }
        case .waiting, .aimed, .travelling, .landed:
            end(because: "the voice ended before the name")
        case .over:
            return
        }
    }

    func stop() {
        end(because: "the question stopped")
    }

    private func depart(taking duration: Duration) {
        guard case .aimed(let target) = phase else { return }
        departing = nil
        let bounds = CGRect(origin: .zero, size: displayFrame.size)
        let rest = viewPoint(cursorRest())
        let start = CGPoint(
            x: min(max(rest.x, bounds.minX), bounds.maxX),
            y: min(max(rest.y, bounds.minY), bounds.maxY)
        )
        let travel = Travel(from: start, to: viewPoint(target), within: bounds, duration: duration, startingAt: .now)
        panel.show(on: displayFrame)
        overlay.start(travel)
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
        overlay.land()
        phase = .landed
        logger.notice("The cursor landed")
        if isNameStarted {
            showMark()
        }
    }

    private func showMark() {
        overlay.mark()
        phase = .marked
        logger.notice("The mark is on")
    }

    private func clearLater() {
        clearing = Task { [weak self] in
            try? await Task.sleep(for: Self.clearAfterLine)
            guard !Task.isCancelled else { return }
            self?.end(because: "two seconds passed after its line", fading: true)
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
        if wasShowing, !fading {
            panel.hide()
        }
        overlay.clear()
        if wasShowing, fading {
            hideAfterFade()
        }
        logger.notice("Pointing ended: \(reason, privacy: .public); it was showing: \(wasShowing, privacy: .public)")
    }

    private func hideAfterFade() {
        hiding = Task { [panel, overlay] in
            try? await Task.sleep(for: Self.fadeOut)
            guard overlay.travel == nil else { return }
            panel.hide()
        }
    }

    private func viewPoint(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - displayFrame.minX, y: displayFrame.maxY - screenPoint.y)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
