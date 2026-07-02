import SwiftUI

/// Entry point.
///
/// dynotch runs as a menu-bar *agent* (no Dock icon). The actual notch UI is an
/// `NSPanel` owned by `AppDelegate` and is added in Milestone 1 — at this stage
/// the app only installs a menu-bar item so the framework builds and launches.
@main
struct DynotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No main window: this is an agent app. Preferences live in the standard
        // Settings scene (fleshed out in Milestone 6).
        Settings {
            SettingsView()
        }
    }
}
