import AppKit

/// Owns process-wide, non-SwiftUI concerns: the menu-bar status item and, from
/// Milestone 1 onward, the notch `NSPanel`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()

        // TODO: Milestone 1 — create and show the notch NSPanel here
        //       (see NotchWindowController / NotchPanel).
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "dynotch"
        )

        let menu = NSMenu()
        let header = NSMenuItem(title: "dynotch — early WIP", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit dynotch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }
}
