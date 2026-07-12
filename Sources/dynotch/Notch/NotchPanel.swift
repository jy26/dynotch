import AppKit

/// The always-on-top, borderless panel that draws over the physical notch:
/// `[.borderless, .nonactivatingPanel]` style, clear background, `.statusBar`
/// level, and `[.canJoinAllSpaces, .fullScreenAuxiliary]` collection behavior so
/// it stays visible across Spaces and over full-screen apps.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar                 // above .mainMenu (menu bar / notch)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false          // stay visible when the app isn't active
    }

    /// The panel is normally never key — first-mouse clicks keep the user's app in
    /// focus (no focus theft). But a text field (the timer's duration editor) needs
    /// the window to become key to take keyboard input; a non-activating panel can
    /// do that Spotlight-style without activating the app. Non-text clicks still
    /// arrive as first mouse, so focus only moves here when you click into the field.
    override var canBecomeKey: Bool { true }
}
