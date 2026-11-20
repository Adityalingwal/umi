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
    private var waitingForAccess: Task<Void, Never>?

    init(accessibility: AccessibilityPermission) {
        self.accessibility = accessibility
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        (escapes, escapeContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    func start() {
        guard waitingForAccess == nil, monitors.isEmpty else { return }
        waitingForAccess = Task { [weak self, accessibility] in
            while accessibility.currentAccess() != .allowed {
                try? await Task.sleep(for: Self.accessCheckInterval)
                guard !Task.isCancelled else { return }
            }
            self?.listen()
        }
    }

    func stop() {
        waitingForAccess?.cancel()
        waitingForAccess = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
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

    private func listen() {
        waitingForAccess = nil
        let otherApps = NSEvent.addGlobalMonitorForEvents(matching: Self.keyEvents) { [weak self] event in
            self?.handle(event)
        }
        let umi = NSEvent.addLocalMonitorForEvents(matching: Self.keyEvents) { [weak self] event in
            self?.handle(event)
            return event
        }
        monitors = [otherApps, umi].compactMap(\.self)
        logger.notice("Listening for the right Option key")
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
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
