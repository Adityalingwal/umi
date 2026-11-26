import AppKit
import Carbon.HIToolbox
import OSLog

final class KeyListener {
    private static let escapeKeyCode = UInt16(kVK_Escape)
    private static let accessCheckInterval = Duration.seconds(1)
    // Clicks are heard only so that Command+click is not taken for a Command press.
    private static let events: NSEvent.EventTypeMask = [
        .flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown
    ]

    let holds: AsyncStream<HoldEvent>
    let escapes: AsyncStream<Void>
    let commandDoublePresses: AsyncStream<Void>

    private let accessibility: AccessibilityPermission
    private let holdContinuation: AsyncStream<HoldEvent>.Continuation
    private let escapeContinuation: AsyncStream<Void>.Continuation
    private let commandDoublePressContinuation: AsyncStream<Void>.Continuation
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Umi", category: "Voice")
    private var hold = RightOptionHold()
    private var commandDoublePress = CommandDoublePress()
    private var monitors: [Any] = []
    private var isHearingHold = false
    private var waitingForAccess: Task<Void, Never>?

    init(accessibility: AccessibilityPermission) {
        self.accessibility = accessibility
        (holds, holdContinuation) = AsyncStream.makeStream(of: HoldEvent.self)
        (escapes, escapeContinuation) = AsyncStream.makeStream(of: Void.self)
        (commandDoublePresses, commandDoublePressContinuation) = AsyncStream.makeStream(of: Void.self)
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
        commandDoublePressContinuation.finish()
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
        let umi = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            self?.handle(event)
            return event
        }
        monitors = [umi].compactMap(\.self)
        logger.notice("Listening for Esc in Umi's own windows")
    }

    // Without the grant a release in another app goes unseen, so a hold is heard only once both monitors run.
    private func listenInOtherApps() {
        waitingForAccess = nil
        let otherApps = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] event in
            self?.handle(event)
        }
        monitors += [otherApps].compactMap(\.self)
        isHearingHold = true
        logger.notice("Listening for the right Option key")
    }

    // Secure input hides other apps' key presses, so a shortcut typed there looks like Command alone.
    private func commandPressedTwice() {
        guard !IsSecureEventInputEnabled() else {
            logger.notice("Command was pressed twice while secure input is on, so it is ignored")
            return
        }
        logger.notice("Command was pressed twice")
        commandDoublePressContinuation.yield()
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            let flags = event.modifierFlags
            if commandDoublePress.modifiersChanged(keyCode: event.keyCode, flags: flags, at: event.timestamp) {
                commandPressedTwice()
            }
            guard isHearingHold else { return }
            if let change = hold.modifiersChanged(keyCode: event.keyCode, flags: flags) {
                holdContinuation.yield(change)
            }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            commandDoublePress.otherInput()
        case .keyDown:
            commandDoublePress.otherInput()
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
