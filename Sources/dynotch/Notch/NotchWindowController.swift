import AppKit
import SwiftUI

/// Creates the `NotchPanel`, positions it over the notch, and keeps it in sync
/// with live display changes (dock/undock, clamshell open/close, resolution).
///
/// Milestone 1 positions the panel over the notch and shows/hides it as displays
/// come and go; Milestone 2 adds hover-driven resize between the collapsed and
/// expanded frames.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var screenObserver: NSObjectProtocol?

    /// Places the panel over the notch (if any) and starts observing display
    /// changes so it repositions / shows / hides live. Call once at launch.
    func start() {
        guard screenObserver == nil else { return }   // idempotent: safe to call once
        updatePlacement()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on `.main`, so we're already on the main actor.
            MainActor.assumeIsolated { self?.updatePlacement() }
        }
    }

    /// Idempotent: shows + positions the panel over the current notch, or hides
    /// it when no notched display is present. Safe to call repeatedly.
    private func updatePlacement() {
        guard let screen = ScreenGeometry.notchedScreen(),
              let notch = ScreenGeometry.notchRect(for: screen) else {
            panel?.orderOut(nil)          // no notch → hide cleanly, keep for reuse
            return
        }
        let panel = ensurePanel()
        panel.setFrame(notch, display: true)   // notch rect is in global screen coords
        panel.orderFrontRegardless()           // show without activating the app
    }

    /// Lazily builds the reusable panel with its static SwiftUI content.
    private func ensurePanel() -> NotchPanel {
        if let panel { return panel }
        let panel = NotchPanel(contentRect: .zero)   // setFrame supplies the rect
        panel.contentView = NSHostingView(rootView: NotchView())
        self.panel = panel
        return panel
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    // TODO: Milestone 2 — resize between collapsed and expanded frames.
}
