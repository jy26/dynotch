import SwiftUI

/// The notch surface. Collapsed: a black pill flush with the hardware notch — square
/// top corners, rounded bottom — so it merges into the physical notch. Expanded (on
/// hover): the panel grows it (AppKit); this view morphs the bottom corner radius and
/// fades in the media UI on the same clock, so the two read as one motion.
struct NotchView: View {
    @EnvironmentObject private var state: NotchState
    @EnvironmentObject private var nowPlaying: NowPlaying
    @EnvironmentObject private var timer: TimerActivity

    private var expanded: Bool { state.presentation == .expanded }
    /// Anything worth a collapsed indicator (5.4): media or a running timer.
    private var hasCollapsedContent: Bool {
        nowPlaying.title != nil || timer.state != nil
    }
    private var showsIndicator: Bool { !expanded && hasCollapsedContent }
    private var showsHome: Bool { expanded && state.tab == .home }
    private var showsMedia: Bool { expanded && state.tab == .media }
    private var showsShelf: Bool { expanded && state.tab == .shelf }
    private var showsActivities: Bool { expanded && state.tab == .activities }

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: expanded ? 24 : 10,
            bottomTrailingRadius: expanded ? 24 : 10,
            topTrailingRadius: 0
        )
        .fill(Color.black)
        .overlay(alignment: .top) {
            // Home (default landing surface): clock + date/greeting + glances.
            HomeView()
                .frame(width: ScreenGeometry.expandedSize.width,
                       height: ScreenGeometry.expandedSize.height)
                .opacity(showsHome ? 1 : 0)
                .allowsHitTesting(showsHome)
        }
        .overlay(alignment: .top) {
            // One stable instance, opacity-gated (an `if expanded` transition
            // churns view identity and flickers on quick re-hover). Fixed at the
            // final expanded size and top-anchored: the growing panel reveals it
            // without reflowing. The 1 Hz ticker while collapsed is negligible.
            MediaPlayerView()
                .frame(width: ScreenGeometry.expandedSize.width,
                       height: ScreenGeometry.expandedSize.height)
                .opacity(showsMedia ? 1 : 0)
                .allowsHitTesting(showsMedia)   // no ghost clicks while collapsed
        }
        .overlay(alignment: .top) {
            // Shelf (4.2): same stable, opacity-gated pattern; a file drag over
            // the panel switches the tab to reveal it.
            ShelfView()
                .frame(width: ScreenGeometry.expandedSize.width,
                       height: ScreenGeometry.expandedSize.height)
                .opacity(showsShelf ? 1 : 0)
                .allowsHitTesting(showsShelf)
        }
        .overlay(alignment: .top) {
            // Activities (5.3): battery + timer; same stable, opacity-gated pattern.
            ActivityView()
                .frame(width: ScreenGeometry.expandedSize.width,
                       height: ScreenGeometry.expandedSize.height)
                .opacity(showsActivities ? 1 : 0)
                .allowsHitTesting(showsActivities)
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
        .overlay(alignment: .topLeading) {
            // Tab switcher (5.3): media / shelf / activities, in the reserved top
            // band left of the notch. Last overlay so it sits above the surfaces;
            // fades with the panel via the presentation animation below.
            NotchTabBar()
                .padding(.leading, 18)
                .padding(.top, 8)
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill the panel bounds
        .animation(.easeOut(duration: NotchState.animationDuration), value: state.presentation)
        .animation(.easeOut(duration: NotchState.animationDuration), value: hasCollapsedContent)
        .animation(.easeOut(duration: NotchState.animationDuration), value: state.tab)
    }
}

/// The tab switcher (5.3, + Home). Plain SwiftUI `Button`s — they receive clicks in
/// the never-key panel via `ClickThroughHostingView`'s first-mouse (the media
/// controls / shelf ✕ prove it). The active tab is bright, the rest dimmed.
private struct NotchTabBar: View {
    @EnvironmentObject private var state: NotchState

    private static let tabs: [(tab: NotchState.Tab, symbol: String)] = [
        (.home, "house.fill"),
        (.media, "music.note"),
        (.shelf, "tray.full"),
        (.activities, "bolt.fill"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Self.tabs, id: \.symbol) { tab, symbol in
                Button {
                    state.tab = tab
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(state.tab == tab ? 0.95 : 0.4))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
