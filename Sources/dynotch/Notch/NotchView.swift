import SwiftUI

/// The notch surface. Collapsed: a black pill flush with the hardware notch — square
/// top corners, rounded bottom — so it merges into the physical notch. Expanded (on
/// hover): the panel grows it (AppKit); this view morphs the bottom corner radius and
/// fades in a placeholder on the same clock, so the two read as one motion.
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
        .overlay {
            // M2 placeholder — M3 swaps in the real media UI here.
            Text("dyNotch")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.55))
                .opacity(expanded ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill the panel bounds
        .animation(.easeOut(duration: NotchState.animationDuration), value: state.presentation)
    }
}
