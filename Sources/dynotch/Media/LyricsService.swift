import Combine
import Foundation

/// One parsed line of synced (LRC) lyrics.
struct LyricLine: Equatable {
    let time: TimeInterval
    let text: String
}

/// Fetched lyrics outcome for one track.
enum TrackLyrics {
    case synced([LyricLine])
    case plain(String)
    case instrumental
    case none            // looked up, no match
}

/// Fetches lyrics for the current track from LRCLIB (lrclib.net) — 3.8.
///
/// Privacy gate: lookups fire only for real music apps (Spotify, Apple Music);
/// browser-sourced media (e.g. YouTube titles) never leaves the machine. Each
/// lookup sends exactly title / artist / album / duration — no identifiers.
/// The endpoint is keyless and unthrottled; a courtesy User-Agent names the app.
/// Verified contract (2026-07-04): duration tolerance ±2 s, `album_name`
/// optional, no match is a clean JSON 404, instrumentals are flagged.
///
/// Log-only for now: `current` holds the parsed result for M5's lyrics UI, but
/// nothing reads it yet — the log lines are this increment's deliverable.
@MainActor
final class LyricsService: ObservableObject {
    private static let musicApps: Set<String> = ["com.spotify.client", "com.apple.Music"]
    private static let endpoint = "https://lrclib.net/api/get"
    private static let userAgent = "dyNotch/0.1 (https://github.com/jy26/dynotch)"

    @Published private(set) var current: TrackLyrics?

    private let nowPlaying: NowPlaying
    private var cache: [String: TrackLyrics] = [:]   // hits AND 404 misses
    private var identityCancellable: AnyCancellable?
    private var prefsCancellable: AnyCancellable?
    /// Identity key the current fetch/`current` belongs to — a late response is
    /// dropped if the track changed while it was in flight.
    private var activeKey: String?
    /// In-flight lookup. Cancelled the moment the track changes again — which
    /// is what makes zero-debounce fetching safe during rapid skips: each
    /// superseded request is aborted instead of completing.
    private var fetchTask: Task<Void, Never>?

    init(nowPlaying: NowPlaying) {
        self.nowPlaying = nowPlaying
    }

    /// Observes track identity, deduplicated so pause/seek payloads never
    /// re-trigger. Fetches immediately on change (cancelling any in-flight
    /// lookup); stale lyrics are dropped and cache hits applied in the same
    /// breath, so pop-up latency is just the network round-trip.
    func start() {
        let np = nowPlaying
        identityCancellable = np.objectWillChange
            .receive(on: DispatchQueue.main)   // read state AFTER the change lands
            .map { _ in MainActor.assumeIsolated { Self.identity(of: np) } }
            .removeDuplicates()
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
        // Re-evaluate when the "Show lyrics" pref flips, so it clears/loads live (6.1).
        prefsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification, object: Prefs.suite)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluate() }
            }
    }

    /// Track identity for dedup — everything a lookup depends on.
    private static func identity(of np: NowPlaying) -> String {
        "\(np.title ?? "")|\(np.artist ?? "")|\(np.album ?? "")"
            + "|\(Int(np.duration.rounded()))|\(np.sourceBundleID ?? "")"
    }

    private func evaluate() {
        guard Prefs.showsLyrics else {           // opt-out (6.1) — no lookups, clear the UI
            fetchTask?.cancel()
            activeKey = nil
            current = nil
            return
        }
        guard let title = nowPlaying.title, !title.isEmpty,
              let artist = nowPlaying.artist, !artist.isEmpty,
              nowPlaying.duration > 0 else {
            fetchTask?.cancel()
            activeKey = nil
            current = nil
            return
        }
        let source = nowPlaying.sourceBundleID ?? "unknown"
        guard Self.musicApps.contains(source) else {
            fetchTask?.cancel()
            activeKey = nil
            current = nil
            log("lyrics: skipped (source \(source))")
            return
        }
        let duration = Int(nowPlaying.duration.rounded())
        let key = "\(title)|\(artist)|\(nowPlaying.album ?? "")|\(duration)"
        guard key != activeKey else { return }
        fetchTask?.cancel()
        activeKey = key
        if let cached = cache[key] {
            current = cached
            log("lyrics: cache hit for \"\(title)\" — \(artist)")
            return
        }
        current = nil   // the old track's lines never linger over a new song
        let album = nowPlaying.album
        fetchTask = Task { [weak self] in
            await self?.fetch(key: key, title: title, artist: artist,
                              album: album, duration: duration)
        }
    }

    private func fetch(key: String, title: String, artist: String,
                       album: String?, duration: Int) async {
        var components = URLComponents(string: Self.endpoint)!
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(duration)),
        ]
        if let album, !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = items
        guard let url = components.url else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let result: TrackLyrics
            switch status {
            case 200:
                let decoded = try JSONDecoder().decode(LrclibResponse.self, from: data)
                if decoded.instrumental == true {
                    result = .instrumental
                } else if let lrc = decoded.syncedLyrics, !lrc.isEmpty {
                    result = .synced(Self.parseLRC(lrc))
                } else if let plain = decoded.plainLyrics, !plain.isEmpty {
                    result = .plain(plain)
                } else {
                    result = .none
                }
            case 404:
                result = .none
            default:
                // Not cached — a transient server error retries on the next track change.
                log("lyrics: fetch failed (HTTP \(status)) for \"\(title)\"")
                return
            }
            cache[key] = result
            switch result {
            case .synced(let lines):
                log("lyrics: \(lines.count) synced lines for \"\(title)\" — \(artist)")
            case .plain:
                log("lyrics: plain only (no sync) for \"\(title)\" — \(artist)")
            case .instrumental:
                log("lyrics: instrumental — \"\(title)\"")
            case .none:
                log("lyrics: no match for \"\(title)\" — \(artist)")
            }
            if activeKey == key { current = result }   // drop if track changed mid-fetch
        } catch is CancellationError {
            // Superseded by a newer track — expected during rapid skips; silent.
        } catch let error as URLError where error.code == .cancelled {
            // Same, surfaced as a URLError by URLSession.
        } catch {
            log("lyrics: fetch failed for \"\(title)\": \(error.localizedDescription)")
        }
    }

    /// Parses LRC text: `[mm:ss.xx] line`. Tolerates multiple timestamps per
    /// line ("[00:12.00][00:45.00] chorus"); metadata tags like `[ar:…]` don't
    /// match the numeric pattern and fall out naturally.
    private static func parseLRC(_ lrc: String) -> [LyricLine] {
        let tag = #/\[(\d+):(\d+(?:\.\d+)?)\]/#
        var lines: [LyricLine] = []
        for raw in lrc.split(separator: "\n", omittingEmptySubsequences: true) {
            let matches = raw.matches(of: tag)
            guard let last = matches.last else { continue }
            let text = String(raw[last.range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            for match in matches {
                guard let minutes = Double(match.1), let seconds = Double(match.2) else { continue }
                lines.append(LyricLine(time: minutes * 60 + seconds, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    private func log(_ message: String) {
        print("[dyNotch] \(message)")
        fflush(stdout)
    }
}

/// The fields dyNotch uses from LRCLIB's response (the rest are ignored).
private struct LrclibResponse: Decodable {
    let syncedLyrics: String?
    let plainLyrics: String?
    let instrumental: Bool?
}
