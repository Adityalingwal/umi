import AppKit
import SwiftUI

final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let microphoneItem = NSMenuItem(title: "", action: #selector(microphoneItemClicked), keyEquivalent: "")
    private let screenItem = NSMenuItem(title: "", action: #selector(screenItemClicked), keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "",
        action: #selector(accessibilityItemClicked),
        keyEquivalent: ""
    )
    private let microphone: MicrophonePermission
    private let screen: ScreenPermission
    private let accessibility: AccessibilityPermission
    private let keyListener: KeyListener
    private let listening: Listening
    private let relauncher: AppRelauncher
    private var screenRefresh: Task<Void, Never>?

    init(
        appName: String,
        microphone: MicrophonePermission,
        screen: ScreenPermission,
        accessibility: AccessibilityPermission,
        keyListener: KeyListener,
        listening: Listening,
        relauncher: AppRelauncher
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.microphone = microphone
        self.screen = screen
        self.accessibility = accessibility
        self.keyListener = keyListener
        self.listening = listening
        self.relauncher = relauncher
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: appName)
        statusItem.menu = makeMenu(appName: appName)
    }

    func open() {
        statusItem.button?.performClick(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        showMicrophone(microphone.currentAccess())
        showScreen(screen.lastKnownAccess)
        refreshScreen()
        showAccessibility(accessibility.currentAccess())
    }

    func menuWillOpen(_ menu: NSMenu) {
        listening.menuDidOpen()
    }

    func menuDidClose(_ menu: NSMenu) {
        listening.menuDidClose()
        keyListener.menuDidClose()
    }

    private func makeMenu(appName: String) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let nameItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        nameItem.isEnabled = false
        menu.addItem(nameItem)
        menu.addItem(.separator())
        for item in [microphoneItem, screenItem, accessibilityItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(makeLevelItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func makeLevelItem() -> NSMenuItem {
        let hostingView = NSHostingView(rootView: LevelBar().environment(listening))
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: 240, height: hostingView.fittingSize.height))
        hostingView.autoresizingMask = .width
        let item = NSMenuItem()
        item.view = hostingView
        return item
    }

    private func refreshScreen() {
        screenRefresh?.cancel()
        screenRefresh = Task { [weak self] in
            guard let self else { return }
            let access = await screen.currentAccess()
            guard !Task.isCancelled else { return }
            showScreen(access)
        }
    }

    private func showMicrophone(_ access: MicrophoneAccess) {
        microphoneItem.title = "Microphone: \(access.rowStatus)"
        microphoneItem.isEnabled = access != .allowed
    }

    private func showScreen(_ access: ScreenAccess) {
        screenItem.title = "Screen: \(access.rowStatus)"
        screenItem.isEnabled = access != .allowed
    }

    private func showAccessibility(_ access: AccessibilityAccess) {
        accessibilityItem.title = "Accessibility: \(access.rowStatus)"
        accessibilityItem.isEnabled = access != .allowed
    }

    @objc private func microphoneItemClicked() {
        switch microphone.currentAccess() {
        case .notAsked:
            Task {
                showMicrophone(await microphone.requestAccess())
            }
        case .denied:
            microphone.openSystemSettings()
        case .allowed:
            break
        }
    }

    @objc private func screenItemClicked() {
        switch screen.lastKnownAccess {
        case .notAsked:
            Task {
                showScreen(await screen.requestAccess())
            }
        case .denied:
            screen.openSystemSettings()
        case .needsRelaunch:
            Task {
                await relauncher.relaunch()
            }
        case .allowed:
            break
        }
    }

    @objc private func accessibilityItemClicked() {
        switch accessibility.currentAccess() {
        case .notAsked:
            showAccessibility(accessibility.requestAccess())
        case .denied:
            accessibility.openSystemSettings()
        case .allowed:
            break
        }
    }
}

private extension MicrophoneAccess {
    var rowStatus: String {
        switch self {
        case .notAsked: "Allow…"
        case .allowed: "Allowed"
        case .denied: "Denied"
        }
    }
}

private extension ScreenAccess {
    var rowStatus: String {
        switch self {
        case .notAsked: "Allow…"
        case .allowed: "Allowed"
        case .denied: "Denied"
        case .needsRelaunch: "Relaunch Umi"
        }
    }
}

private extension AccessibilityAccess {
    var rowStatus: String {
        switch self {
        case .notAsked: "Allow…"
        case .allowed: "Allowed"
        case .denied: "Denied"
        }
    }
}
