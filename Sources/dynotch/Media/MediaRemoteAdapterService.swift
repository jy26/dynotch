import Foundation
import MediaRemoteAdapter

/// Bridges to the mediaremote-adapter package (a Perl script + adapter dylib)
/// to read now-playing metadata and send playback commands.
///
/// This is the workaround for the macOS 15.4+ MediaRemote entitlement lock-down:
/// the system Perl binary (`com.apple.perl`) is still granted MediaRemote access,
/// so we drive it out-of-process. We own the perl spawn rather than using the
/// package's `MediaController`, whose dylib-path resolution
/// (`Bundle(for:).executablePath`) only works inside an .app bundle with the
/// product embedded as a framework — under bare `swift run` it resolves to our
/// executable. See docs/ARCHITECTURE.md.
@MainActor
final class MediaRemoteAdapterService {
    // TODO: Milestone 3.2 — spawn `loop` via Process, parse JSON lines into
    //       NowPlaying, and send playback commands (`play`, `pause_command`,
    //       `next_track`, `previous_track`). Replaces the smoke test below.

    /// TEMPORARY (3.1): proves the perl → dylib chain works under `swift run`.
    /// Locates the adapter artifacts next to our executable
    /// (`.build/<triple>/debug/` under `swift run`), runs a one-shot `get`, and
    /// logs the result. Removed in 3.2, which keeps the same locate-and-spawn
    /// pattern for the streaming `loop` command.
    static func runAdapterSmokeTest() {
        // Referencing the module's type proves the dependency linked and loaded.
        print("[dyNotch] mediaremote-adapter linked: \(MediaController.self)")

        let dir = Bundle.main.bundleURL
        let dylib = dir.appendingPathComponent("libMediaRemoteAdapter.dylib")
        let fm = FileManager.default
        // run.pl ships in the package's resource bundle; scan for it rather than
        // hardcoding the bundle's name (derived from the package manifest).
        let runPL = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "bundle" }
            .compactMap { Bundle(url: $0)?.path(forResource: "run", ofType: "pl") }
            .first
        guard fm.fileExists(atPath: dylib.path), let runPL else {
            print("[dyNotch] mediaremote-adapter smoke test FAILED: "
                + "dylib or run.pl not found next to executable at \(dir.path)")
            fflush(stdout)
            return
        }

        DispatchQueue.global().async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            process.arguments = [runPL, dylib.path, "get"]   // run.pl <dylib> <command>
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            do {
                try process.run()
                // Drain stdout BEFORE waiting: payloads carry base64 artwork and can
                // exceed the ~64KB pipe buffer — waitUntilExit first would deadlock
                // (child blocked writing, us blocked waiting).
                let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                                    encoding: .utf8) ?? ""
                process.waitUntilExit()
                // Payloads can be large (base64 artwork) — log a truncated preview.
                let preview = stdout.isEmpty
                    ? "no output (is media playing?) stderr: \(stderr.prefix(200))"
                    : String(stdout.prefix(200))
                print("[dyNotch] mediaremote-adapter smoke test "
                    + "(exit \(process.terminationStatus), \(stdout.utf8.count) bytes): \(preview)")
            } catch {
                print("[dyNotch] mediaremote-adapter smoke test FAILED to launch perl: \(error)")
            }
            fflush(stdout)
        }
    }
}
