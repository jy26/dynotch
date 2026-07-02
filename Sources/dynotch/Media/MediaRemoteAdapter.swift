import Foundation

/// Bridges to the bundled `mediaremote-adapter` (a Perl script + helper
/// framework) to read now-playing metadata and send playback commands.
///
/// This is the workaround for the macOS 15.4+ MediaRemote entitlement
/// lock-down: the system Perl binary (`com.apple.perl`) is still granted
/// MediaRemote access, so we drive it out-of-process. Implemented in Milestone 3.
@MainActor
final class MediaRemoteAdapter {
    // TODO: Milestone 3 — spawn `… stream` via Process, parse JSON lines into
    //       NowPlaying, and send play/pause/next/prev via the `send` command.
}
