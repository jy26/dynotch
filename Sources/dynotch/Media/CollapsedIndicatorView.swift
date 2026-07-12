import SwiftUI

/// Collapsed glanceable indicator (3.5 media + 5.4 activities): two wings flanking
/// the hardware notch. The left wing is the *identity* slot (media artwork, else a
/// charging/timer glyph); the right wing is the *live* slot (a timer countdown, else
/// the visualizer, else the charge percent). The parent frames this view to the
/// collapsed-wide pill size; the fixed-width wings pin to the edges and the Spacer
/// spans the (invisible) notch strip between them.
struct CollapsedIndicatorView: View {
    @EnvironmentObject private var nowPlaying: NowPlaying
    @EnvironmentObject private var timer: TimerActivity

    /// True only while visible AND playing — gates the visualizer's schedule so
    /// a hidden or paused indicator costs nothing.
    let animating: Bool

    private var hasMedia: Bool { nowPlaying.title != nil }

    var body: some View {
        HStack(spacing: 0) {
            leftWing
                .frame(width: ScreenGeometry.collapsedWingWidth)   // left wing
            Spacer(minLength: 0)          // spans the hardware notch — stays empty
            rightWing
                .frame(width: ScreenGeometry.collapsedWingWidth)   // right wing
        }
    }

    /// Identity slot: media artwork, else a timer glyph.
    @ViewBuilder private var leftWing: some View {
        if hasMedia {
            artworkThumb
        } else if timer.state != nil {
            wingGlyph("timer")
        }
    }

    /// Live slot: the timer countdown, else the visualizer.
    @ViewBuilder private var rightWing: some View {
        if let state = timer.state {
            Text(state.isFinished ? "Done" : state.clock)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else if hasMedia {
            AudioBarsView(animating: animating)
        }
    }

    private func wingGlyph(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.85))
    }

    @ViewBuilder
    private var artworkThumb: some View {
        Group {
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Four EQ-style bars. Purely decorative — MediaRemote exposes no real audio
/// data — animated by a paused-gated `TimelineView` so the schedule stops
/// entirely (zero ticks) whenever the indicator is hidden or playback pauses.
private struct AudioBarsView: View {
    let animating: Bool

    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2
    private static let minHeight: CGFloat = 4
    private static let maxHeight: CGFloat = 16
    private static let pausedHeight: CGFloat = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(0..<4, id: \.self) { bar in
                    Capsule()
                        .fill(.white.opacity(0.85))
                        .frame(width: Self.barWidth,
                               height: animating ? Self.height(bar: bar, at: t) : Self.pausedHeight)
                }
            }
            .frame(height: Self.maxHeight, alignment: .bottom)      // EQ-style, bottom-anchored
            .animation(.easeOut(duration: 0.25), value: animating)  // settle to the frozen bars
        }
    }

    /// Two incommensurate sines per bar, phase-offset per bar — organic enough
    /// to read as "audio", cheap, and deterministic (no state to desync).
    private static func height(bar: Int, at t: TimeInterval) -> CGFloat {
        let phase = Double(bar) * 1.7
        let unit = 0.5 + 0.30 * sin(t * 2.9 + phase) + 0.20 * sin(t * 4.3 + phase * 1.3)
        return minHeight + (maxHeight - minHeight) * CGFloat(min(max(unit, 0), 1))
    }
}
