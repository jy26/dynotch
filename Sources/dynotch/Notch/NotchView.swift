import SwiftUI

/// The notch surface. Collapsed: a black pill flush with the hardware notch — square
/// top corners, rounded bottom — so it merges into the physical notch. Expanded (on
/// hover): the panel grows it (AppKit); this view morphs the bottom corner radius and
/// fades in the media UI on the same clock, so the two read as one motion.
struct NotchView: View {
    @EnvironmentObject private var state: NotchState
    @EnvironmentObject private var nowPlaying: NowPlaying

    private var expanded: Bool { state.presentation == .expanded }
    private var showsIndicator: Bool { !expanded && nowPlaying.title != nil }

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
        .overlay(alignment: .top) {
            // Collapsed indicator (3.5): fixed at the collapsed-wide size and
            // top-anchored, so it crossfades out in place as the panel expands.
            // Stable + opacity-gated (identity churn flickers — the 3.3 lesson).
            CollapsedIndicatorView(animating: showsIndicator && nowPlaying.isPlaying)
                .frame(width: state.collapsedSize.width + 2 * ScreenGeometry.collapsedWingWidth,
                       height: state.collapsedSize.height)
                .opacity(showsIndicator ? 1 : 0)
                .allowsHitTesting(false)      // decorative
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill the panel bounds
        .animation(.easeOut(duration: NotchState.animationDuration), value: state.presentation)
        .animation(.easeOut(duration: NotchState.animationDuration), value: nowPlaying.title != nil)
    }
}
