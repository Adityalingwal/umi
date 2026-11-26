import AppKit
import Carbon.HIToolbox
import OSLog

final class KeyListener {
    private static let escapeKeyCode = UInt16(kVK_Escape)
    private static let accessCheckInterval = Duration.seconds(1)
    private static let keyEvents: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]

    let holds: AsyncStream<HoldEvent>
    let escapes: AsyncStream<Void>

    private let accessibility: AccessibilityPermission
    private let holdContinuation: AsyncStream<HoldEvent>.Continuation
    private let escapeContinuation: AsyncStream<Void>.Continuation
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var hold = RightOptionHold()
    private var monitors: [Any] = []
    private var isHearingHold = false
    private var waitingForAccess: Task<Void, Never>?

    init(accessibility: AccessibilityPermission) {
        self.accessibility = accessibility
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        (escapes, escapeContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    func start() {
        guard waitingForAccess == nil, monitors.isEmpty else { return }
        listenInUmi()
        waitingForAccess = Task { [weak self, accessibility] in
            while accessibility.currentAccess() != .allowed {
                try? await Task.sleep(for: Self.accessCheckInterval)
                guard !Task.isCancelled else { return }
            }
            self?.listenInOtherApps()
        }
    }

    func stop() {
        waitingForAccess?.cancel()
        waitingForAccess = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        isHearingHold = false
        holdContinuation.finish()
        escapeContinuation.finish()
    }

    func menuDidClose() {
        guard hold.isKeyDown,
              !CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(RightOptionHold.keyCode)) else {
            return
        }
        logger.notice("The right Option key was released while Umi's menu was open")
        if let release = hold.keyWasReleased() {
            holdContinuation.yield(release)
        }
    }

    // Keys typed into Umi's own panel reach it without the Accessibility grant, so Esc works there before it.
    private func listenInUmi() {
        let umi = NSEvent.addLocalMonitorForEvents(matching: Self.keyEvents) { [weak self] event in
            self?.handle(event)
            return event
        }
        monitors = [umi].compactMap(\.self)
        logger.notice("Listening for Esc in Umi's own windows")
    }

    // Without the grant a release in another app goes unseen, so a hold is heard only once both monitors run.
    private func listenInOtherApps() {
        waitingForAccess = nil
        let otherApps = NSEvent.addGlobalMonitorForEvents(matching: Self.keyEvents) { [weak self] event in
            self?.handle(event)
        }
        monitors += [otherApps].compactMap(\.self)
        isHearingHold = true
        logger.notice("Listening for the right Option key")
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            guard isHearingHold else { return }
            if let change = hold.modifiersChanged(keyCode: event.keyCode, flags: event.modifierFlags) {
                holdContinuation.yield(change)
            }
        case .keyDown:
            if let cancel = hold.keyPressed() {
                holdContinuation.yield(cancel)
            } else if event.keyCode == Self.escapeKeyCode, !hold.isKeyDown {
                escapeContinuation.yield()
            }
        default:
            return
        }
    }
}
