import AppKit

/// Computes the notch rectangle for a screen, derived from
/// `NSScreen.safeAreaInsets.top` (height) and the `auxiliaryTopLeftArea` /
/// `auxiliaryTopRightArea` menu-bar strips that flank the notch (width).
enum ScreenGeometry {
    /// The notch rect for `screen`, in that screen's coordinates (y-up, origin
    /// bottom-left), or `nil` on displays without a notch.
    static func notchRect(for screen: NSScreen) -> CGRect? {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }

        let height = screen.safeAreaInsets.top
        let minX = left.maxX
        let width = right.minX - minX
        guard width > 0 else { return nil }

        return CGRect(x: minX,
                      y: screen.frame.maxY - height,
                      width: width,
                      height: height)
    }

    /// The first screen that has a notch (the built-in display), if any.
    static func notchedScreen() -> NSScreen? {
        NSScreen.screens.first { notchRect(for: $0) != nil }
    }
}
