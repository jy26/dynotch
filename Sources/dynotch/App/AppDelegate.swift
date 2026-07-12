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
    private let weather = WeatherService()
    // lazy: a stored-property initializer can't reference another stored property.
    private lazy var mediaService = MediaRemoteAdapterService(nowPlaying: nowPlaying)
    private lazy var lyricsService = LyricsService(nowPlaying: nowPlaying)
    private lazy var notchController = NotchWindowController(
        nowPlaying: nowPlaying,
        lyrics: lyricsService,
        shelf: shelf,
        battery: battery,
        timer: timer,
        weather: weather,
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
        weather.start()
        notchController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaService.stop()
        battery.stop()
        weather.stop()
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
        menu.addItem(
            withTitle: "Quit dyNotch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        item.menu = menu
        statusItem = item
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
