import AppKit

/// Owns process-wide, non-SwiftUI concerns: the menu-bar status item and, from
/// Milestone 1 onward, the notch `NSPanel`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let nowPlaying = NowPlaying()
    private let shelf = ShelfModel()
    // lazy: a stored-property initializer can't reference another stored property.
    private lazy var mediaService = MediaRemoteAdapterService(nowPlaying: nowPlaying)
    private lazy var lyricsService = LyricsService(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying,
        lyrics: lyricsService,
        sendPlaybackCommand: { [weak self] in self?.mediaService.send($0) },
        sendSeek: { [weak self] in self?.mediaService.seek(to: $0) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar agent: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        logNotchGeometry()
        mediaService.start()
        lyricsService.start()
        shelf.start()
        notchController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService.stop()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "dyNotch"
        )

        let menu = NSMenu()
        let header = NSMenuItem(title: "dyNotch — early WIP", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // TEMP 4.1 — shelf verification triggers; removed in 4.2 when the real
        // drop target lands.
        let addItem = NSMenuItem(title: "Shelf: Add File…",
                                 action: #selector(shelfAddFile), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)
        let listItem = NSMenuItem(title: "Shelf: List",
                                  action: #selector(shelfList), keyEquivalent: "")
        listItem.target = self
        menu.addItem(listItem)
        let removeItem = NSMenuItem(title: "Shelf: Remove Last",
                                    action: #selector(shelfRemoveLast), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)
        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit dyNotch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }

    // TEMP 4.1 — shelf verification triggers; removed in 4.2.
    @objc private func shelfAddFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            shelf.add(panel.urls)
        }
    }

    @objc private func shelfList() {
        if shelf.items.isEmpty {
            print("[dyNotch] shelf: (empty)")
        } else {
            for (index, url) in shelf.items.enumerated() {
                print("[dyNotch] shelf[\(index)]: \(url.path)")
            }
        }
        fflush(stdout)
    }

    @objc private func shelfRemoveLast() {
        guard let last = shelf.items.last else {
            print("[dyNotch] shelf: nothing to remove")
            fflush(stdout)
            return
        }
        shelf.remove(last)
    }

    /// Logs the detected notch geometry for the built-in display (Milestone 1.1
    /// verification). Uses `print` so it shows in the terminal under `swift run`.
    private func logNotchGeometry() {
        if let screen = ScreenGeometry.notchedScreen(),
           let notch = ScreenGeometry.notchRect(for: screen) {
            print("[dyNotch] Notch on \(screen.localizedName): "
                + "origin=(\(notch.origin.x), \(notch.origin.y)) "
                + "size=\(notch.width)×\(notch.height) pt "
                + "(safeAreaInsets.top=\(screen.safeAreaInsets.top))")
        } else {
            print("[dyNotch] No notch detected on any screen.")
        }
        fflush(stdout)  // ensure the diagnostic is emitted even when piped/redirected
    }
}
