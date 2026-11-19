import AppKit

final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let microphoneItem = NSMenuItem(title: "", action: #selector(microphoneItemClicked), keyEquivalent: "")
    private let screenItem = NSMenuItem(title: "", action: #selector(screenItemClicked), keyEquivalent: "")
    private let microphone: MicrophonePermission
    private let screen: ScreenPermission
    private let relauncher: AppRelauncher
    private var screenRefresh: Task<Void, Never>?

    init(appName: String, microphone: MicrophonePermission, screen: ScreenPermission, relauncher: AppRelauncher) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.microphone = microphone
        self.screen = screen
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
    }

    private func makeMenu(appName: String) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let nameItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        nameItem.isEnabled = false
        menu.addItem(nameItem)
        menu.addItem(.separator())
        for item in [microphoneItem, screenItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
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
