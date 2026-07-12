import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService` (Milestone 6.2). The OS is the source of truth — no
/// persisted bool; the toggle reflects and drives `SMAppService.mainApp.status`. This only
/// works when running as the packaged `.app` (a login item is a real bundle); under bare
/// `swift run` there's no bundle, so `register()` throws and this just logs.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[dyNotch] launch-at-login: \(enabled ? "register" : "unregister") failed: "
                + error.localizedDescription)
            fflush(stdout)
        }
    }
}
