import SwiftUI

/// The notch surface. Collapsed: a black pill flush with the hardware notch — square
/// top corners, rounded bottom — so it merges into the physical notch. Expanded (on
/// hover): the panel grows it (AppKit); this view morphs the bottom corner radius and
/// fades in the media UI on the same clock, so the two read as one motion.
struct NotchView: View {
    @EnvironmentObject private var state: NotchState

    private var expanded: Bool { state.presentation == .expanded }

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: expanded ? 24 : 10,
            bottomTrailingRadius: expanded ? 24 : 10,
            topTrailingRadius: 0
        )
        .fill(Color.black)
        .overlay(alignment: .top) {
            // One stable instance, opacity-gated (an `if expanded` transition
            // churns view identity and flickers on quick re-hover). Fixed at the
            // final expanded size and top-anchored: the growing panel reveals it
            // without reflowing. The 1 Hz ticker while collapsed is negligible.
            MediaPlayerView()
                .frame(width: ScreenGeometry.expandedSize.width,
                       height: ScreenGeometry.expandedSize.height)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)   // no ghost clicks while collapsed
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill the panel bounds
        .animation(.easeOut(duration: NotchState.animationDuration), value: state.presentation)
    }
}
