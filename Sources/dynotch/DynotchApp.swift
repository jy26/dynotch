import SwiftUI

/// Entry point.
///
/// dyNotch runs as a menu-bar *agent* (no Dock icon). The notch UI — an `NSPanel` —
/// and all long-lived services are owned by `AppDelegate`.
@main
struct DynotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // An `App` needs at least one `Scene`, but this agent app has no SwiftUI
        // window: an `.accessory` app never reaches the `Settings` scene (no app menu
        // → `showSettingsWindow:` has no handler). The real settings window is a manual
        // `NSWindow` in `AppDelegate.openSettings()`; this is a no-op placeholder.
        Settings {
            EmptyView()
        }
    }
}
