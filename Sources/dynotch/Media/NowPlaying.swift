import AppKit
import Combine

/// Observable now-playing state, populated live by `MediaRemoteAdapterService`.
/// `elapsed`/`duration` are event-time snapshots in seconds; live progress
/// ticking is the UI's job (Milestone 3.3).
@MainActor
final class NowPlaying: ObservableObject {
    @Published var title: String?
    @Published var artist: String?
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0
}
