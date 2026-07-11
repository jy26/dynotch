import AppKit

/// Owns process-wide, non-SwiftUI concerns: the menu-bar status item and, from
/// Milestone 1 onward, the notch `NSPanel`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let nowPlaying = NowPlaying()
    private let shelf = ShelfModel()
    private let battery = BatteryMonitor()
    private let timer = TimerActivity()
    // lazy: a stored-property initializer can't reference another stored property.
    private lazy var mediaService = MediaRemoteAdapterService(nowPlaying: nowPlaying)
    private lazy var lyricsService = LyricsService(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying,
        lyrics: lyricsService,
        shelf: shelf,
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
        battery.start()
        notchController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService.stop()
        battery.stop()
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
        addTimerTriggers(to: menu)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit dyNotch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
    }

    // TEMP (Milestone 5.2): pre-UI triggers to exercise the timer activity, mirroring
    // 4.1's throwaway shelf triggers. Removed once a real "set a timer" UI lands.
    private func addTimerTriggers(to menu: NSMenu) {
        for (title, action) in [
            ("Start 10 s timer", #selector(startTenSecondTimer)),
            ("Start 1 min timer", #selector(startOneMinuteTimer)),
            ("Cancel timer", #selector(cancelTimer)),
        ] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
    }

    @objc private func startTenSecondTimer() { timer.start(10) }
    @objc private func startOneMinuteTimer() { timer.start(60) }
    @objc private func cancelTimer() { timer.cancel() }

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
