# dyNotch — Roadmap

Built incrementally: each item below is roughly one commit — a small,
self-contained change with its own "Done when" check. We complete a milestone one
increment at a time and verify each before moving on. This mirrors the approved
project plan.

Legend: `[x]` done · `[ ]` not started.

## Milestone 0 — Framework & docs ✅

- [x] **0.1** Repo hygiene — project root at repo root; single `.git` (origin
  `jy26/dynotch` preserved); `.gitignore` added.
- [x] **0.2** `README.md` — overview, target, MVP features, build/run, status.
- [x] **0.3** `docs/ARCHITECTURE.md` — window model, notch geometry, media adapter,
  module map.
- [x] **0.4** `docs/ROADMAP.md` — this checklist.
- [x] **0.5** `LICENSE` placeholder (TBD).
- [x] **0.6** SwiftPM app skeleton — menu-bar agent (`.accessory`, no Dock icon),
  `NSStatusItem` with Quit; `swift build` succeeds.
- [x] **0.7** Module layout stubs — Notch / Media / Shelf / Activities / State /
  Settings placeholder types; project still builds.

## Milestone 1 — Notch window skeleton

- [x] **1.1** `ScreenGeometry` — compute the notch rect from `safeAreaInsets.top`
  + `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`. *Done when:* logs correct
  notch dimensions on the built-in display. ✅ verified: 185×32 pt, centered.
- [x] **1.2** `NotchPanel` — borderless, non-activating, transparent, `.statusBar`,
  all-Spaces; show a temporary tinted rect at the notch. *Done when:* the rect
  sits over the notch and is visible on every Space. ✅ verified on-device: tint
  sits over the notch, persists across Spaces and full-screen apps.
- [x] **1.3** Collapsed pill — black rounded pill sized to the notch. *Done when:*
  it visually merges with the physical notch. ✅ verified on-device: merges cleanly
  (UnevenRoundedRectangle, square top / rounded bottom, ~10 pt).
- [x] **1.4** Display edge cases — no-notch / external displays hide cleanly (no
  fallback pill), and the panel repositions/shows/hides on live display changes
  (`didChangeScreenParametersNotification`). *Done when:* external monitor &
  non-notched Macs behave. ✅ verified on-device: dock/undock, clamshell, lid-open,
  resolution change (185×32 ↔ 220×38, always centered), and sleep/wake all correct.

## Milestone 2 — Hover & expansion

- [x] **2.1** Hover detection (`NSTrackingArea` / mouse monitor) → `NotchState`.
  *Done when:* hover toggles state. ✅ verified on-device: an `.activeAlways` tracking
  area fires enter/exit reliably even while another app is frontmost.
- [x] **2.2** Panel resize animation between collapsed and expanded frames. ✅ verified
  on-device: hover animates the panel down/out and back (0.28 s ease-out); a
  geometry-guarded exit prevents expand/collapse oscillation.
- [x] **2.3** SwiftUI content container that morphs collapsed ↔ expanded in sync.
  *Done when:* hover expands smoothly, leaving collapses. ✅ verified on-device: size,
  bottom-corner radius, and content fade land together.
- [x] **2.4** Click-through — menu bar outside the notch stays interactive. ✅ verified
  on-device: collapsed panel = notch rect, so the flanking menu bar stays fully
  clickable. The expanded panel overlaps the usually-empty center menu bar — evaluated
  shift-down / collapse-on-approach dodges and kept the simpler overlap (revisit in M3).

## Milestone 3 — Media & now-playing (MVP)

- [x] **3.1** Integrate `mediaremote-adapter` (ejbills SwiftPM fork, pinned by
  revision); smoke-test the perl → dylib chain under `swift run`; document in
  ARCHITECTURE.md + THIRD-PARTY.md. ✅ verified on-device: one-shot `get` returned
  a live Spotify payload (exit 0, ~159 KB incl. artwork) through perl → dylib →
  MediaRemote. Build needs `CC=clang` (shell exports a GNU gcc).
- [x] **3.2** `MediaRemoteAdapterService` — spawn `loop`, parse JSON →
  `NowPlaying`. *Done when:* it logs live track changes. ✅ verified on-device:
  live track/pause/resume logs across Spotify **and** Brave (system-wide source
  switching); kill → auto-restart (×3 cap) works; no orphaned perl after quit.
- [x] **3.3** Expanded media UI — artwork, title, artist, live progress. ✅ verified
  on-device: artwork/title/artist render below the notch; progress extrapolates
  between payloads (0.5 s tick), holds steady through pause/unpause via a
  measurement-timestamp staleness guard (fresh seeks pass, any direction), and
  the hover surface stays glitch-free (stable overlay identity; top-edge
  tolerance in the exit guard).
- [x] **3.4** Controls — play/pause/next/prev via the loop's stdin commands
  (`play`, `pause`, `toggle_play_pause`, `next_track`, `previous_track`).
  *Done when:* verified against Apple Music **and** Spotify, controls round-trip.
  ✅ verified on-device: full matrix round-trips against **both** Spotify and
  Apple Music (toggle/next/prev, icon driven by the stream). Caveat: Music
  ignores skip commands for queue-less single-file content — Control Center
  hides those buttons for the same reason (the app advertises no skip support);
  with a real queue, skips work. Click delivery via `acceptsFirstMouse` (no key
  status, no focus theft). Polish note: gray out unsupported commands if the
  adapter ever exposes the supported-command set.
- [ ] **3.5** Collapsed now-playing — mini indicator / visualizer.

## Milestone 4 — File shelf (MVP)

- [ ] **4.1** `ShelfModel` — held files as security-scoped bookmarks; persist.
- [ ] **4.2** Drop-in target in the expanded view. *Done when:* dragged files
  appear and persist.
- [ ] **4.3** Drag-out back to Finder / other apps.
- [ ] **4.4** AirDrop via `NSSharingService`.

## Milestone 5 — Live activities (MVP)

- [ ] **5.1** Battery/charging monitor (IOKit) → activity model.
- [ ] **5.2** Timer activity (start / tick / finish).
- [ ] **5.3** Tab/state system so media, shelf, and activities share the expanded
  view.
- [ ] **5.4** Collapsed glanceable indicators for active activities.

## Milestone 6 — Polish & distribution

- [ ] **6.1** Settings window + `@AppStorage` prefs.
- [ ] **6.2** Launch at login (`SMAppService`).
- [ ] **6.3** Code signing + notarization pipeline.
- [ ] **6.4** Sparkle auto-update; keep a clean licensing/paywall seam. *Not* Mac
  App Store (private-framework dependency).

## Milestone 7 — Optional (post-MVP)

- [ ] **7.1** HUD replacement — volume (CoreAudio listener) / brightness sliders
  that animate from the notch. Deferred: suppressing the native HUD is the
  hardest part.

## Deferred decisions

- License / paywall (OSS vs commercial) — architecture keeps this open; decide
  before public release. Sign + notarize either way.
- Which live activities beyond charging + timer (AirDrop, focus mode, …).
- Whether to build HUD replacement (M7) at all.
- Expanded-panel menu-bar overlap — while expanded the panel covers the (usually
  empty) center of the menu bar. Kept the simple overlap for now (M2.4). Options to
  revisit if it conflicts with real content: (a) **shift-down on approach** —
  temporarily slide the panel below the bar when the cursor nears it, then rise back;
  (b) **collapse on approach** — collapse the instant the cursor heads for a menu;
  (c) **island neck** — keep a notch-width neck through the menu-bar row and flare
  below it, so the bar is never covered. A first spike of (a)/(b) didn't feel right;
  they'd need refinement.
