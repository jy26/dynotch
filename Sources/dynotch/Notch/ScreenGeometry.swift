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

/// Collapsed + expanded panel frames, both in global screen coords (y-up).
struct NotchFrames {
    let collapsed: CGRect
    let expanded: CGRect
}

extension ScreenGeometry {
    /// Milestone 2 placeholder — real size arrives with M3–5 content.
    static let expandedSize = CGSize(width: 520, height: 180)

    /// Expanded panel: top edge flush with the screen top, centered on the notch,
    /// grows down + outward. Guarantees `expanded ⊇ collapsed` so the cursor that
    /// triggered expansion stays inside the grown rect (no hover oscillation).
    ///
    /// While expanded this overlaps the (usually empty) center of the menu bar. M2.4
    /// kept the simple overlap; dodge options for later are noted in
    /// docs/ROADMAP.md → Deferred decisions.
    static func frames(for screen: NSScreen, collapsed notch: CGRect) -> NotchFrames {
        let size = expandedSize
        let top = notch.maxY                    // == screen.frame.maxY (flush top)
        var x = notch.midX - size.width / 2
        x = min(max(x, screen.frame.minX), screen.frame.maxX - size.width)   // clamp on-screen
        let expanded = CGRect(x: x, y: top - size.height, width: size.width, height: size.height)
        return NotchFrames(collapsed: notch, expanded: expanded)
    }
}
