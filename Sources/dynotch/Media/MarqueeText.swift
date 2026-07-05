import SwiftUI

/// Single-line text that hugs its content up to `maxWidth`; longer text scrolls
/// horizontally (marquee) within that window. Short text therefore frees its
/// leftover width to siblings instead of reserving the full window. Inherits
/// font/foreground from the environment.
struct MarqueeText: View {
    let text: String
    /// Widest the view will grow; longer text scrolls within this window.
    let maxWidth: CGFloat
    /// Animates only while true (and only when overflowing) — the 3.5 lesson:
    /// zero animation frames while the panel is collapsed.
    var active: Bool = true

    @State private var textWidth: CGFloat = 0

    private static let gap: CGFloat = 28    // gap between the looped copies
    private static let speed: Double = 25   // scroll speed, pt/s
    private static let hold: Double = 1.8   // pause at the start of each loop

    var body: some View {
        let overflows = textWidth > maxWidth + 1
        Group {
            if overflows {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { context in
                    HStack(spacing: Self.gap) {
                        measured
                        measured   // second copy → seamless wrap-around
                    }
                    .offset(x: -Self.phase(at: context.date, loop: textWidth + Self.gap))
                }
            } else {
                measured
            }
        }
        .frame(width: min(max(textWidth, 1), maxWidth), alignment: .leading)
        .clipped()
    }

    /// The text plus an invisible width probe.
    private var measured: some View {
        Text(text)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { textWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in textWidth = width }
            })
    }

    /// Piecewise loop: hold, scroll one full copy + gap, wrap (invisible thanks
    /// to the duplicated copy), repeat.
    private static func phase(at date: Date, loop: CGFloat) -> CGFloat {
        guard loop > 0 else { return 0 }
        let period = hold + Double(loop) / speed
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return t <= hold ? 0 : CGFloat((t - hold) * speed)
    }
}
