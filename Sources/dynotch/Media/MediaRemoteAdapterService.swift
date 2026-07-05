import AppKit
import Foundation
// TrackInfo — the fork's decoder handles isPlaying Bool-or-Int, PID-as-string,
// and base64 → NSImage. @preconcurrency: the module predates strict concurrency;
// TrackInfo is a value struct handed across the queue→main hop once.
@preconcurrency import MediaRemoteAdapter

/// Playback commands understood by the adapter loop's stdin reader
/// (`executeInlineCommand` in MediaRemoteAdapter.m). Raw value == wire format.
enum PlaybackCommand: String {
    case play
    case pause
    case togglePlayPause = "toggle_play_pause"
    case nextTrack = "next_track"
    case previousTrack = "previous_track"
}

/// Streams now-playing metadata from the mediaremote-adapter package (a Perl
/// script + adapter dylib) into `NowPlaying`.
///
/// This is the workaround for the macOS 15.4+ MediaRemote entitlement lock-down:
/// the system Perl binary (`com.apple.perl`) is still granted MediaRemote access,
/// so we drive it out-of-process. We own the perl spawn rather than using the
/// package's `MediaController`, whose dylib-path resolution
/// (`Bundle(for:).executablePath`) only works inside an .app bundle with the
/// product embedded as a framework — under bare `swift run` it resolves to our
/// executable. See docs/ARCHITECTURE.md.
///
/// The `loop` command emits one full JSON payload per line (this fork never sends
/// diffs), the literal line `NIL` when nothing is playing, and nothing at all for
/// payloads with an empty title. It reads playback commands from stdin — we hold
/// the stdin pipe now so Milestone 3.4's controls can write to it.
@MainActor
final class MediaRemoteAdapterService {
    private static let maxRestartAttempts = 3

    private let nowPlaying: NowPlaying
    private var process: Process?
    private var stdinPipe: Pipe?          // loop's command channel — used in 3.4
    private var isStopping = false
    private var restartAttempts = 0

    /// Last logged (title, artist, isPlaying, bundleIdentifier) — dedupes the
    /// now-playing log so elapsed-only payloads don't spam.
    private var lastLogged: (String?, String?, Bool, String?)?

    init(nowPlaying: NowPlaying) {
        self.nowPlaying = nowPlaying
        // A command write can race the child's death: without this, writing to a
        // broken pipe raises SIGPIPE and kills dyNotch before write(contentsOf:)
        // can throw. Process-wide and idempotent; the fork does the same.
        signal(SIGPIPE, SIG_IGN)
    }

    /// Sends one playback command down the loop's stdin (newline-delimited).
    /// Fire-and-forget: state comes back via the stream, never from here.
    func send(_ command: PlaybackCommand) {
        writeLine(command.rawValue)
    }

    /// Seeks to an absolute position via the loop's `set_time <seconds>` command
    /// (parsed with `doubleValue`, routed to MRMediaRemoteSetElapsedTime).
    /// Optimistically moves the local position so the bar doesn't flash back to
    /// the pre-seek extrapolation while the confirming payload is in flight.
    func seek(to seconds: TimeInterval) {
        let target = max(0, seconds)
        writeLine("set_time " + String(format: "%.2f", target))
        nowPlaying.elapsed = target
        nowPlaying.elapsedAt = Date()
    }

    private func writeLine(_ line: String) {
        guard let handle = stdinPipe?.fileHandleForWriting else {
            print("[dyNotch] command \(line) dropped — adapter loop not running")
            fflush(stdout)
            return
        }
        do {
            try handle.write(contentsOf: Data((line + "\n").utf8))
            print("[dyNotch] sent command: \(line)")
            fflush(stdout)
        } catch {
            print("[dyNotch] command \(line) write failed: \(error)")
            fflush(stdout)
        }
    }

    /// Locates the adapter artifacts and spawns the streaming loop. Safe to call
    /// again after termination (the restart path does exactly that).
    func start() {
        guard let artifacts = Self.locateArtifacts() else {
            print("[dyNotch] media adapter FAILED: dylib or run.pl not found next to executable")
            fflush(stdout)
            return
        }
        spawnLoop(runPL: artifacts.runPL, dylibPath: artifacts.dylibPath)
    }

    /// Terminates the child. Belt — the adapter's own parent watchdog (ppid poll
    /// every 5 s) is the suspenders that covers even SIGKILL of dyNotch.
    func stop() {
        isStopping = true
        process?.terminate()
    }

    /// The adapter artifacts land next to our executable (`.build/<triple>/debug/`
    /// under `swift run`): the dylib as a sibling file, run.pl inside the package's
    /// resource bundle — scanned for rather than hardcoding the bundle's name.
    private static func locateArtifacts() -> (runPL: String, dylibPath: String)? {
        let dir = Bundle.main.bundleURL
        let dylib = dir.appendingPathComponent("libMediaRemoteAdapter.dylib")
        let fm = FileManager.default
        guard fm.fileExists(atPath: dylib.path) else { return nil }
        let runPL = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "bundle" }
            .compactMap { Bundle(url: $0)?.path(forResource: "run", ofType: "pl") }
            .first
        guard let runPL else { return nil }
        return (runPL, dylib.path)
    }

    private func spawnLoop(runPL: String, dylibPath: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = [runPL, dylibPath, "loop"]
        let out = Pipe(), err = Pipe(), input = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = input   // never inherit the TTY; command channel for 3.4

        // Line buffer, touched only on the FileHandle callback queue (serial per
        // handle) — payloads with artwork (~160 KB) arrive across many chunks.
        let buffer = LineBuffer()
        let newline = Data("\n".utf8)
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {          // EOF — clear or the handler spins hot
                handle.readabilityHandler = nil
                return
            }
            buffer.data.append(chunk)
            while let nl = buffer.data.firstRange(of: newline) {   // drain ALL complete lines
                let line = buffer.data.subdata(in: buffer.data.startIndex..<nl.lowerBound)
                buffer.data.removeSubrange(buffer.data.startIndex..<nl.upperBound)
                Self.dispatchLine(line, to: self)
            }
        }

        err.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            if let text = String(data: chunk, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("[dyNotch] adapter stderr: \(text.trimmingCharacters(in: .newlines))")
                fflush(stdout)
            }
        }

        p.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handleTermination(status: proc.terminationStatus) }
            }
        }

        do {
            try p.run()
            process = p
            stdinPipe = input
            print("[dyNotch] media adapter loop started (pid \(p.processIdentifier))")
            fflush(stdout)
        } catch {
            print("[dyNotch] media adapter FAILED to launch perl: \(error)")
            fflush(stdout)
        }
    }

    /// Runs on the FileHandle callback queue: decodes there (base64 artwork →
    /// NSImage stays off the main thread), then hops to the main actor. The
    /// DispatchQueue.main hop preserves line order (per-line Tasks would not).
    private nonisolated static func dispatchLine(_ line: Data, to service: MediaRemoteAdapterService?) {
        guard !line.isEmpty else { return }
        if line == Data("NIL".utf8) {
            DispatchQueue.main.async { MainActor.assumeIsolated { service?.applyNothingPlaying() } }
            return
        }
        do {
            let info = try JSONDecoder().decode(TrackInfo.self, from: line)
            DispatchQueue.main.async { MainActor.assumeIsolated { service?.apply(info.payload) } }
        } catch {
            let preview = String(data: line.prefix(120), encoding: .utf8) ?? "<binary>"
            print("[dyNotch] adapter decode error: \(error) line: \(preview)")
            fflush(stdout)
        }
    }

    private func apply(_ payload: TrackInfo.Payload) {
        restartAttempts = 0   // healthy stream → reset the crash-loop budget

        // Position carried forward to now under the OLD playing state — captured
        // before mutating, so payloads without elapsed info (late artwork, some
        // pause events) don't reset the clock to 0.
        let now = Date()
        let carriedElapsed = nowPlaying.displayedElapsed(at: now)

        let sameTrack = payload.title == nowPlaying.title && payload.artist == nowPlaying.artist
        nowPlaying.title = payload.title
        nowPlaying.artist = payload.artist
        nowPlaying.album = payload.album
        nowPlaying.sourceBundleID = payload.bundleIdentifier
        // Artwork transiently drops to null on the same track (right after track
        // changes, before art loads) — keep the last image rather than flickering.
        if !sameTrack || payload.artwork != nil {
            nowPlaying.artwork = payload.artwork
        }
        nowPlaying.isPlaying = payload.isPlaying ?? false
        nowPlaying.duration = (payload.durationMicros ?? 0) / 1_000_000
        if let elapsed = payload.currentElapsedTime {
            // Stale-data guard: pause/unpause payloads can carry a position
            // measured seconds ago, which would blip the bar backwards. Trust the
            // payload's own measurement timestamp — a real seek (any direction,
            // any size) is freshly measured and passes through; only an OLD
            // snapshot that moves us backward on the same track gets held.
            let age = payload.timestampEpochMicros
                .map { Date().timeIntervalSince1970 - $0 / 1_000_000 } ?? 0
            if sameTrack, elapsed < carriedElapsed, age > 2 {
                nowPlaying.elapsed = carriedElapsed
            } else {
                nowPlaying.elapsed = elapsed
            }
        } else if sameTrack {
            nowPlaying.elapsed = carriedElapsed   // no elapsed in this payload — keep position
        } else {
            nowPlaying.elapsed = 0                // new track with no position info
        }
        nowPlaying.elapsedAt = now   // the UI extrapolates live progress from here

        let key = (payload.title, payload.artist, payload.isPlaying ?? false, payload.bundleIdentifier)
        if lastLogged == nil || lastLogged! != key {
            lastLogged = key
            let app = payload.applicationName.map { " [\($0)]" } ?? ""
            print("[dyNotch] now playing: \(payload.title ?? "?") — \(payload.artist ?? "?") "
                + "(\(payload.isPlaying == true ? "playing" : "paused"))\(app)")
            fflush(stdout)
        }
    }

    private func applyNothingPlaying() {
        nowPlaying.title = nil
        nowPlaying.artist = nil
        nowPlaying.album = nil
        nowPlaying.sourceBundleID = nil
        nowPlaying.artwork = nil
        nowPlaying.isPlaying = false
        nowPlaying.elapsed = 0
        nowPlaying.duration = 0
        nowPlaying.elapsedAt = nil
        if lastLogged != nil {
            lastLogged = nil
            print("[dyNotch] now playing: nothing")
            fflush(stdout)
        }
    }

    /// Mutable line buffer captured by the stdout readability handler.
    /// @unchecked Sendable: FileHandle invokes the handler serially per handle,
    /// so `data` is only ever touched from that one callback queue.
    private final class LineBuffer: @unchecked Sendable {
        var data = Data()
    }

    private func handleTermination(status: Int32) {
        process = nil
        stdinPipe = nil
        print("[dyNotch] adapter loop exited (status \(status))")
        fflush(stdout)
        guard !isStopping, restartAttempts < Self.maxRestartAttempts else { return }
        restartAttempts += 1
        print("[dyNotch] adapter loop restarting (attempt \(restartAttempts)/\(Self.maxRestartAttempts))")
        fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isStopping else { return }
                self.start()
            }
        }
    }
}
