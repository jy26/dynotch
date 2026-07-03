import AppKit

/// AppKit content view for the notch panel. Hosts the SwiftUI `NotchView` and owns
/// the hover tracking area.
///
/// `.activeAlways` makes mouse enter/exit fire even though the panel is
/// non-activating and never key; `.inVisibleRect` makes the tracked rect follow the
/// view as the panel resizes collapsed ↔ expanded (Milestone 2.2), so we don't have
/// to re-add the area on every frame change.
final class NotchContainerView: NSView {
    /// Called with `true` on mouse-enter and `false` on mouse-exit (after a short
    /// debounce). The controller routes this into `NotchState.presentation`.
    var onHoverChange: ((Bool) -> Void)?

    /// Debounce so a brief exit at the pill's edge doesn't flicker the state.
    private let exitDebounce: TimeInterval = 0.09
    private var pendingExit: DispatchWorkItem?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: .zero,                                       // ignored under .inVisibleRect
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        pendingExit?.cancel()
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        // Resizing the panel churns the `.inVisibleRect` tracking area every frame,
        // which emits a spurious exit even though the cursor never left. Trust
        // geometry, not the event: only collapse if the cursor is really outside the
        // (possibly mid-animation) panel frame — otherwise we'd loop expand↔collapse.
        // Inset by -2: a cursor pinned at the very top of the screen reports
        // y == frame.maxY, which CGRect.contains excludes — without the tolerance,
        // pushing into the notch reads as an exit and bounces the panel once.
        guard let window,
              !window.frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) else { return }
        let work = DispatchWorkItem { [weak self] in self?.onHoverChange?(false) }
        pendingExit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + exitDebounce, execute: work)
    }
}
