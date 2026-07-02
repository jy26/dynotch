import AppKit

/// Computes the notch rectangle for a given screen.
///
/// The real implementation lands in Milestone 1, deriving the notch from
/// `NSScreen.safeAreaInsets.top` (height) and the `auxiliaryTopLeftArea` /
/// `auxiliaryTopRightArea` menu-bar strips (width).
enum ScreenGeometry {
    /// The notch rect in screen coordinates, or `nil` on displays without a notch.
    static func notchRect(for screen: NSScreen) -> CGRect? {
        // TODO: Milestone 1 — derive from safeAreaInsets + auxiliary top areas.
        return nil
    }
}
