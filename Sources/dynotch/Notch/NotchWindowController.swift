import AppKit
import Combine
import SwiftUI

/// Creates the `NotchPanel`, positions it over the notch, and keeps it in sync
/// with live display changes (dock/undock, clamshell open/close, resolution).
///
/// Milestone 1 positions the panel over the notch and shows/hides it as displays
/// come and go; Milestone 2 adds hover-driven resize between the collapsed and
/// expanded frames.
@MainActor
final class NotchWindowController {
    private let state = NotchState()
    private var panel: NotchPanel?
    private var frames: NotchFrames?
    private var screenObserver: NSObjectProtocol?
    private var presentationCancellable: AnyCancellable?

    /// Places the panel over the notch (if any) and starts observing display
    /// changes so it repositions / shows / hides live. Call once at launch.
    func start() {
        guard screenObserver == nil else { return }   // idempotent: safe to call once
        updatePlacement()
        presentationCancellable = state.$presentation
            .removeDuplicates()
            .sink { [weak self] presentation in
                self?.applyPresentation(presentation, animated: true)
            }
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
        frames = ScreenGeometry.frames(for: screen, collapsed: notch)
        applyPresentation(state.presentation, animated: false)   // reposition for the new frames
        panel.orderFrontRegardless()           // show without activating the app
    }

    /// Sizes the panel to the collapsed or expanded frame, animating the resize on
    /// hover transitions and snapping instantly on display changes. AppKit owns the
    /// frame animation; SwiftUI just fills whatever bounds it's given.
    private func applyPresentation(_ presentation: NotchState.Presentation, animated: Bool) {
        guard let panel, let frames else { return }
        let target = (presentation == .expanded) ? frames.expanded : frames.collapsed
        guard panel.frame != target else { return }   // no-op / re-entrancy guard
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = NotchState.animationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    /// Lazily builds the reusable panel: a hover-tracking container hosting the
    /// SwiftUI content. Hover drives `state.presentation`.
    private func ensurePanel() -> NotchPanel {
        if let panel { return panel }
        let panel = NotchPanel(contentRect: .zero)   // setFrame supplies the rect

        let container = NotchContainerView()
        container.onHoverChange = { [weak self] hovering in
            self?.state.presentation = hovering ? .expanded : .collapsed
        }
        let hosting = NSHostingView(rootView: NotchView().environmentObject(state))
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)

        panel.contentView = container
        self.panel = panel
        return panel
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
