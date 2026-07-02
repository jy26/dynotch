import AppKit

/// The always-on-top, borderless panel that draws over the physical notch.
///
/// Configured for real in Milestone 1: `[.borderless, .nonactivatingPanel]`
/// style, clear background, `.statusBar` level, `[.canJoinAllSpaces,
/// .fullScreenAuxiliary]` collection behavior, hosting `NotchView` via an
/// `NSHostingView`.
final class NotchPanel: NSPanel {
    // TODO: Milestone 1 — configure style/level/collection behavior and content.
}
