import AppKit
import Combine

/// Observable now-playing state fed by `MediaRemoteAdapter` (Milestone 3).
@MainActor
final class NowPlaying: ObservableObject {
    @Published var title: String?
    @Published var artist: String?
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // TODO: Milestone 3 — populated from the media-remote adapter stream.
}
