import AppKit

enum StatusMenu {
    static func makeStatusItem(appName: String) -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: appName)
        statusItem.menu = makeMenu(appName: appName)
        return statusItem
    }

    private static func makeMenu(appName: String) -> NSMenu {
        let menu = NSMenu()
        let nameItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        menu.addItem(nameItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
}
