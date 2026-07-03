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

    var body: some View {
        if nowPlaying.title == nil {
            // Nothing playing — the M2 wordmark becomes the empty state.
            Text("dyNotch")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.55))
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
                    Text(nowPlaying.title ?? "")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let artist = nowPlaying.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = nowPlaying.displayedElapsed(at: context.date)
            HStack(spacing: 8) {
                Text(Self.timeString(elapsed))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white.opacity(0.85))
                            .frame(width: geo.size.width * fraction(for: elapsed))
                    }
                }
                .frame(height: 4)
                Text(Self.timeString(nowPlaying.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
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
