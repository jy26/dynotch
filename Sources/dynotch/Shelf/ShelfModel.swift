import Foundation
import Combine

/// Holds files the user has dropped into the notch shelf, persisted as
/// bookmarks in `~/Library/Application Support/dyNotch/shelf.plist`.
/// A plist file rather than UserDefaults: the app is an unbundled SwiftPM
/// executable (no bundle ID), so the defaults domain would be implicit
/// process-name magic.
///
/// Plain bookmarks, not `.withSecurityScope`: security-scoped bookmarks are
/// keyed to the creating app's identity, and an unsigned SwiftPM build gets a
/// new ad-hoc identity on every rebuild — every rebuild bricked the store
/// ("isn't in the correct format"; verified 2026-07-06 with a foreign-binary
/// probe: scoped resolve fails, plain resolve of the same blob succeeds).
/// Revisit at M6 once the app is signed (stable identity, sandbox-ready).
@MainActor
final class ShelfModel: ObservableObject {
    /// Resolved file URLs in display order (oldest first).
    @Published private(set) var items: [URL] = []

    private struct Entry {
        var url: URL
        var bookmark: Data
    }

    private var entries: [Entry] = []

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("dyNotch/shelf.plist")
    }()

    /// Loads persisted bookmarks, pruning broken ones (file deleted) and
    /// refreshing stale ones (file moved).
    func start() {
        let blobs: [Data]
        do {
            let raw = try Data(contentsOf: Self.storeURL)
            blobs = try PropertyListDecoder().decode([Data].self, from: raw)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            log("shelf: no store yet, starting empty")
            return
        } catch {
            log("shelf: failed to read store: \(error.localizedDescription)")
            return
        }

        var changed = false
        entries = blobs.compactMap { resolve($0, changed: &changed) }
        publish()
        if changed { save() }
        let pruned = blobs.count - entries.count
        log("shelf: restored \(entries.count) item(s)"
            + (pruned > 0 ? ", pruned \(pruned)" : ""))
    }

    /// Bookmarks and appends each URL; duplicates (same resolved path) are skipped.
    func add(_ urls: [URL]) {
        // Re-resolve held bookmarks first: they track moves, so the dedupe must
        // compare against each file's current path, not its launch-time one.
        var changed = false
        entries = entries.compactMap { resolve($0.bookmark, changed: &changed) }

        var added = 0
        for url in urls {
            guard !entries.contains(where: { $0.url.path == url.path }) else {
                log("shelf: skipped duplicate \(url.lastPathComponent)")
                continue
            }
            do {
                let bookmark = try Self.makeBookmark(for: url)
                entries.append(Entry(url: url, bookmark: bookmark))
                added += 1
                log("shelf: added \(url.lastPathComponent) (bookmark \(bookmark.count) bytes)")
            } catch {
                log("shelf: bookmark failed for \(url.path): \(error.localizedDescription)")
            }
        }
        if added > 0 || changed {
            publish()
            save()
        }
    }

    func remove(_ url: URL) {
        guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
        entries.remove(at: index)
        log("shelf: removed \(url.lastPathComponent)")
        publish()
        save()
    }

    /// Resolves one persisted bookmark to a live entry. Returns nil (prune)
    /// when the bookmark is broken (file gone) or the file now sits in the
    /// Trash — Finder's "delete" is a move, so the bookmark would otherwise
    /// follow the file into the Trash. Sets `changed` whenever the caller
    /// should re-save (refresh or prune).
    private func resolve(_ blob: Data, changed: inout Bool) -> Entry? {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: blob,
                              options: [],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if Self.isInTrash(url) {
                changed = true
                log("shelf: pruned \(url.lastPathComponent) (in Trash)")
                return nil
            }
            var entry = Entry(url: url, bookmark: blob)
            if isStale {
                // File moved: re-create the bookmark from the new location.
                if let fresh = try? Self.makeBookmark(for: url) {
                    entry.bookmark = fresh
                    changed = true
                    log("shelf: refreshed stale bookmark for \(url.path)")
                } else {
                    log("shelf: stale bookmark for \(url.path) (refresh failed, keeping old)")
                }
            }
            return entry
        } catch {
            changed = true
            log("shelf: pruned broken bookmark (\(error.localizedDescription))")
            return nil
        }
    }

    private static func isInTrash(_ url: URL) -> Bool {
        var relationship: FileManager.URLRelationship = .other
        try? FileManager.default.getRelationship(&relationship, of: .trashDirectory,
                                                 in: .userDomainMask, toItemAt: url)
        return relationship == .contains
    }

    private static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [],
                             includingResourceValuesForKeys: nil,
                             relativeTo: nil)
    }

    private func publish() {
        items = entries.map(\.url)
    }

    private func save() {
        do {
            let data = try PropertyListEncoder().encode(entries.map(\.bookmark))
            try FileManager.default.createDirectory(
                at: Self.storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try data.write(to: Self.storeURL, options: .atomic)
            log("shelf: saved \(entries.count) item(s) to \(Self.storeURL.path)")
        } catch {
            log("shelf: save failed: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        print("[dyNotch] \(message)")
        fflush(stdout)
    }
}
