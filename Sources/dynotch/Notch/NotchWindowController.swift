import AppKit
import SwiftUI

/// Creates the `NotchPanel`, positions it over the notch, and shows it.
///
/// Milestone 1 positions the panel statically over the notch; Milestone 2 adds
/// hover-driven resize between the collapsed and expanded frames.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?

    /// Builds the panel over the built-in display's notch and shows it. Does
    /// nothing on setups without a notch (fallback is Milestone 1.4).
    func show() {
        guard let screen = ScreenGeometry.notchedScreen(),
              let notch = ScreenGeometry.notchRect(for: screen) else {
            return
        }

        let panel = NotchPanel(contentRect: notch)
        panel.contentView = NSHostingView(rootView: NotchView())
        panel.setFrame(notch, display: true)   // notch rect is in global screen coords
        panel.orderFrontRegardless()           // show without activating the app
        self.panel = panel
    }

    // TODO: Milestone 2 — resize between collapsed and expanded frames.
}
