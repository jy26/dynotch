import AppKit
import Combine

/// Observable now-playing state, populated live by `MediaRemoteAdapterService`.
/// `elapsed`/`duration` are event-time snapshots in seconds; the UI derives the
/// live position from `displayedElapsed(at:)`.
@MainActor
final class NowPlaying: ObservableObject {
    @Published var title: String?
    @Published var artist: String?
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    /// Wall-clock instant `elapsed` was snapshotted (payload decode time). The UI
    /// extrapolates from here while playing; nil until the first payload.
    @Published var elapsedAt: Date?

    /// Elapsed seconds to display at `date`: the snapshot, extrapolated in real
    /// time while playing (rate 1 assumed between payloads — the service snapshot
    /// already applied the true rate at decode time) and clamped to `duration`.
    func displayedElapsed(at date: Date) -> TimeInterval {
        var value = elapsed
        if isPlaying, let elapsedAt {
            value += date.timeIntervalSince(elapsedAt)
        }
        if duration > 0 { value = min(value, duration) }
        return max(0, value)
    }
}
