import SwiftUI

/// The collapsed notch pill: a black shape matching the physical notch — square
/// top corners (flush with the screen edge) and rounded bottom corners — so it
/// merges into the hardware notch. Milestone 2 grows this into the expanded surface.
struct NotchView: View {
    /// Bottom-corner radius, tuned to match the hardware notch (~10 pt).
    private let bottomCornerRadius: CGFloat = 10

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: bottomCornerRadius,
            bottomTrailingRadius: bottomCornerRadius,
            topTrailingRadius: 0
        )
        .fill(Color.black)
        // TODO: Milestones 3–5 — expanded media / shelf / activities content.
    }
}
