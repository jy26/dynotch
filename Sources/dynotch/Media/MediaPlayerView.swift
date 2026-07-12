import SwiftUI

/// Expanded now-playing UI: artwork, title, artist, and live progress
/// (Milestone 3.3). Hosted by `NotchView` as one stable, opacity-gated overlay
/// (identity churn on expand/collapse flickers). Controls are 3.4.
///
/// Source-agnostic: renders whatever `NowPlaying` holds (any MediaRemote
/// source — Music, Spotify, browsers). Missing fields degrade gracefully:
/// nil artist hides the row, nil artwork shows a placeholder tile, and an
/// unknown duration hides the progress row.
struct MediaPlayerView: View {
    @EnvironmentObject private var nowPlaying: NowPlaying
    @EnvironmentObject private var state: NotchState
    @EnvironmentObject private var lyrics: LyricsService
    @Environment(\.sendPlaybackCommand) private var sendCommand
    @Environment(\.sendSeek) private var sendSeek
    /// Drag position on the progress bar, 0...1; non-nil only mid-scrub, when it
    /// owns the fill and elapsed label instead of the extrapolated position.
    @State private var scrubFraction: CGFloat?

    private var expanded: Bool { state.presentation == .expanded }

    var body: some View {
        if nowPlaying.title == nil {
            // Nothing playing — a quiet empty state (matches the shelf's).
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                Text("Nothing playing")
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            mediaContent
        }
    }

    private var mediaContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                artwork
                VStack(alignment: .leading, spacing: 3) {
                    // Marquee window capped to the controls' width, so the
                    // title/artist/buttons block reads as one square unit and
                    // the lyrics column gets the rest. Short titles hug even
                    // narrower; long ones scroll.
                    MarqueeText(text: nowPlaying.title ?? "", maxWidth: 100, active: expanded)
                        .font(.headline)
                        .foregroundStyle(.white)
                    if let artist = nowPlaying.artist, !artist.isEmpty {
                        MarqueeText(text: artist, maxWidth: 100, active: expanded)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                    controls
                }
                .frame(height: 88)   // pin to artwork height so the Spacer
                                     // bottom-aligns controls without inflating the row
                if let lines = syncedLines {
                    // Lyrics live in the otherwise-empty right half of the row —
                    // no panel growth needed (the height machinery this replaced
                    // is gone from the controller).
                    lyricsView(lines)
                } else {
                    Spacer(minLength: 0)
                }
            }
            if nowPlaying.duration > 0 {
                progress
            }
        }
        .padding(.top, 40)            // clears the hardware-notch strip (32–38 pt)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var artwork: some View {
        Group {
            if let image = nowPlaying.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Ticks twice a second while visible; each tick re-derives elapsed from the
    /// model snapshot, so pause freezes and new payloads snap automatically.
    /// (0.5 s so a fresh track starts moving promptly with floored labels.)
    /// While scrubbing (3.7) the drag location owns the fill and elapsed label;
    /// the seek is sent once, on release.
    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = scrubFraction.map { Double($0) * nowPlaying.duration }
                ?? nowPlaying.displayedElapsed(at: context.date)
            HStack(spacing: 8) {
                Text(Self.timeString(elapsed))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white.opacity(0.85))
                            .frame(width: geo.size.width * fraction(for: elapsed))
                    }
                    .frame(height: 4)
                    .frame(maxHeight: .infinity)      // center the 4 pt bar in the hit zone
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(width: geo.size.width))
                }
                .frame(height: 16)   // grabbable hit zone; the visual bar stays 4 pt
                Text(Self.timeString(nowPlaying.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    /// Click = zero-length drag (minimumDistance 0), so tap-to-seek falls out of
    /// the same gesture. `state.isScrubbing` suppresses the collapse paths while
    /// the drag is active (the cursor may cross the panel edge mid-drag).
    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                state.isScrubbing = true
                scrubFraction = Self.clampedFraction(value.location.x, width: width)
            }
            .onEnded { value in
                let fraction = Self.clampedFraction(value.location.x, width: width)
                sendSeek(Double(fraction) * nowPlaying.duration)
                scrubFraction = nil
                state.isScrubbing = false
            }
    }

    private static func clampedFraction(_ x: CGFloat, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return min(max(x / width, 0), 1)
    }

    /// Play/pause sends `toggle_play_pause` rather than branching on `isPlaying`
    /// (the mirror is stale by construction; toggle always changes real state).
    /// The glyph reads stream state — its flip after a click is the round-trip proof.
    private var controls: some View {
        HStack(spacing: 4) {
            controlButton("backward.fill", size: 13) { sendCommand(.previousTrack) }
            controlButton(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 18) {
                sendCommand(.togglePlayPause)
            }
            controlButton("forward.fill", size: 13) { sendCommand(.nextTrack) }
        }
        .padding(.leading, -9)   // optical: glyph edge (not hit box) aligns with the title
    }

    private func controlButton(_ symbol: String, size: CGFloat,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 32, height: 32)     // comfortable hit target
                .contentShape(Rectangle())        // whole box clickable, not just glyph
        }
        .buttonStyle(NotchControlButtonStyle())
    }

    private var syncedLines: [LyricLine]? {
        if case .synced(let lines)? = lyrics.current, !lines.isEmpty { return lines }
        return nil
    }

    /// How far ahead of the playhead lyrics flip (seconds): community LRC
    /// timestamps often run a touch late, and slightly-early reads better than
    /// slightly-late in karaoke terms. Tunable by feel.
    private static let lyricsLead: TimeInterval = 0.2

    /// Synced-lyrics window (3.9): previous/active/next lines, active centered.
    /// Each row's identity is its line number, so on a line change the active
    /// line itself slides up into the dimmed slot, the next rises in from
    /// below, and the old top row exits — never a content swap. Emphasis is
    /// opacity-only (font-weight flips snap; opacity animates). The active line
    /// stretches to three rows; context lines truncate at one.
    /// Ticks 10×/s — line changes need much tighter granularity than the 0.5 s
    /// progress tick — but only while expanded (paused when hidden, per the 3.5
    /// lesson). Scrubbing previews the line at the scrub target, matching the
    /// elapsed label.
    private func lyricsView(_ lines: [LyricLine]) -> some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !expanded)) { context in
            let elapsed = Self.lyricsLead + (scrubFraction.map { Double($0) * nowPlaying.duration }
                ?? nowPlaying.displayedElapsed(at: context.date))
            let index = lines.lastIndex { $0.time <= elapsed }
            let idx = index ?? -1
            VStack(spacing: 4) {
                ForEach([idx - 1, idx, idx + 1].filter { lines.indices.contains($0) },
                        id: \.self) { i in
                    Text(lines[i].text)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(i == idx ? 0.95 : 0.4))
                        .lineLimit(i == idx ? 3 : 1)   // active stretches; context truncates
                        .truncationMode(.tail)
                        .multilineTextAlignment(.center)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)))
                }
            }
            .frame(height: 88)
            .clipped()
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.3), value: index)
        }
    }

    private func fraction(for elapsed: TimeInterval) -> CGFloat {
        guard nowPlaying.duration > 0 else { return 0 }
        return CGFloat(min(max(elapsed / nowPlaying.duration, 0), 1))
    }

    private static func timeString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))   // floor, matching media-player convention
        let (m, s) = (total / 60, total % 60)
        return m >= 60 ? String(format: "%d:%02d:%02d", m / 60, m % 60, s)
                       : String(format: "%d:%02d", m, s)
    }
}

/// Pressed feedback for the white-on-black control glyphs (`.plain` is
/// near-invisible on black).
private struct NotchControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.45 : 0.9))
    }
}

private struct SendPlaybackCommandKey: EnvironmentKey {
    static let defaultValue: (PlaybackCommand) -> Void = { _ in }   // no-op default
}

private struct SendSeekKey: EnvironmentKey {
    static let defaultValue: (TimeInterval) -> Void = { _ in }   // no-op default
}

extension EnvironmentValues {
    /// Injected by `NotchWindowController`; routes to `MediaRemoteAdapterService.send`.
    var sendPlaybackCommand: (PlaybackCommand) -> Void {
        get { self[SendPlaybackCommandKey.self] }
        set { self[SendPlaybackCommandKey.self] = newValue }
    }

    /// Injected by `NotchWindowController`; routes to `MediaRemoteAdapterService.seek(to:)`.
    var sendSeek: (TimeInterval) -> Void {
        get { self[SendSeekKey.self] }
        set { self[SendSeekKey.self] = newValue }
    }
}
