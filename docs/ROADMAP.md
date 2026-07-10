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
- [x] **3.5** Collapsed now-playing — mini indicator / visualizer. ✅ verified
  on-device: while media is loaded the collapsed pill widens by 36 pt wings —
  mini artwork left, 4-bar decorative visualizer right (paused-gated schedule:
  zero ticks when hidden/paused); bars freeze on pause, pill shrinks to plain
  notch on stop, indicator crossfades in place on expand, steady width across
  track skips (no NIL debounce needed).
- [ ] **3.6** Shuffle + repeat buttons — **blocked on MediaRemote, deferred to
  M6.** Built and reverted 2026-07-04: the stdin toggles work against Apple Music
  (not Spotify — it ignores them), but `shuffleMode`/`repeatMode` are nil in
  every payload (verified incl. forced one-shot snapshots), so state-driven
  button tint is impossible via MediaRemote — the round-trip gate can't be met.
  Future path: AppleScript per-app integration (Music and Spotify both expose
  shuffle/repeat read+write) — needs Automation permission prompts, pairs with
  M6's permission-gated features.
- [x] **3.7** Seek on the progress bar — click/drag → `set_time <seconds>`;
  scrub position owns the bar mid-drag. **Spike first** (lesson from 3.6 / the
  full-screen saga): confirm `set_time` actually moves both players via a
  temporary trigger BEFORE building the drag UI — position *reads* are verified,
  position *writes* are not, and MediaRemote commands are optional for apps.
  *Done when:* forward and backward seeks land in both players with no snap-back.
  ✅ verified on-device: spike (temp ±15 s buttons) proved `set_time` on Spotify
  both directions, 0-clamped, while paused, each seek confirmed by a fresh payload
  ~0.2 s later; then the real UI — `DragGesture(minimumDistance: 0)` on the bar
  (click = zero-length drag), 16 pt hit zone, scrub fraction owns fill + elapsed
  label mid-drag, seek sent once on release — passed the full matrix on **both**
  Spotify and Apple Music with no snap-back (an optimistic local position bridges
  the confirmation gap; `NotchState.isScrubbing` suppresses both collapse paths so
  a drag crossing the panel edge can't fold the panel).
- [x] **3.8** Lyrics service (LRCLIB) — fetch/parse/cache, log-only; the UI lands
  with M5's tab system. Privacy: a lookup sends exactly title/artist/album/duration
  (nothing else), and only for music apps (Spotify, Apple Music) — browser media
  never leaves the machine; M6 settings adds the opt-out toggle. Verified API
  contract (probed live 2026-07-04): keyless, unthrottled, ±2 s duration tolerance,
  `album_name` optional, no-match is a clean JSON 404, instrumentals flagged;
  courtesy User-Agent identifies the app. *Done when:* logs show synced lines for
  a Spotify hit, a graceful no-match, a browser-source skip, and cached re-plays
  (no second fetch). ✅ verified on-device: synced hits (BTS 72 lines, LE SSERAFIM
  36), cache hits on re-play, browser skips, zero refetch on pause/seek, graceful
  404 no-match (obscure track), and artist-less local files gated before any
  request; a late-arriving fetch for a skipped-past track is cached but not
  applied (stale-response guard).
- [x] **3.9** Lyrics UI — synced lyrics render in the otherwise-empty column
  right of the title/controls block in the media row (constant panel size; a
  grow-the-panel approach was built first and discarded with its height
  machinery). Continuity window: prev/active/next rows keyed by **line number**,
  so a line change slides the active line up into the dimmed slot — never a
  content swap; the active line stretches to three rows, context rows truncate
  at one; emphasis is opacity-only (weight flips snap, opacity animates).
  10 Hz tick + 0.2 s lead; residual per-song offset is the community LRC file's
  timing, not ours. Title/artist became `MarqueeText`: hugs its content up to
  the controls' width (~100 pt) so the block reads as a square and short titles
  donate width to lyrics; longer text pauses then loops seamlessly. All lyric
  and marquee animation is paused while collapsed (the 3.5 lesson). Fetch
  pipeline tightened for the UI: zero debounce with in-flight cancellation on
  track change, instant stale-clear, instant cache hits (~1 s to first lyric).
  ✅ verified on-device across Spotify and Apple Music through iterative A/B
  (single-line odometer built, compared, deleted): hits, no-match, browser gate,
  skip-during-fetch, scrub-preview, wide/narrow titles.

## Milestone 4 — File shelf (MVP)

- [x] **4.1** `ShelfModel` — held files as bookmarks; persist. **Plain bookmarks,
  not security-scoped** (plan said scoped): scoped bookmarks are keyed to the
  creating app's identity, and an unsigned SwiftPM build gets a fresh ad-hoc
  identity every rebuild — every rebuild bricked the store ("isn't in the correct
  format"). Confirmed with a foreign-binary probe: scoped resolve of the same
  blob fails, plain resolve succeeds. Revisit scoped at M6 once signing gives a
  stable identity (sandbox prep). Store: `~/Library/Application Support/dyNotch/
  shelf.plist` (explicit file — unbundled executable makes the UserDefaults
  domain implicit). Restore refreshes stale bookmarks (file moved) and prunes
  broken ones (file gone) *and* files sitting in the Trash — Finder "delete" is
  a move the bookmark would otherwise follow (user Trash only; external-volume
  `.Trashes` is an accepted gap). Adds dedupe by current path after re-resolving
  held bookmarks, so a file moved mid-session can't be added twice. ✅ verified
  on-device via temp status-menu triggers (removed in 4.2): add, persist across
  relaunch, move → stale-refresh, Finder-delete → Trash-prune, duplicate (same
  and moved path), remove-last, and cross-rebuild restore of a scoped-era store.
- [x] **4.2** Drop-in target in the expanded view. *Done when:* dragged files
  appear and persist. Drag-triggered expansion is load-bearing: tracking areas
  don't fire mid-drag, so hover can't open the panel — `NSDraggingDestination`
  on `NotchContainerView` does (spike-gated: log-only handlers first proved
  Finder drags reach the non-activating `.statusBar` panel at notch-strip size
  and survive the mid-drag resize). A drag switches `NotchState.tab` to
  `.shelf` (ShelfView joins MediaPlayerView as a stable, opacity-gated
  overlay); drops feed the 4.1 model; after a drop the panel stays expanded
  (geometry check distinguishes drop from drag-out — `draggingEnded` also
  reports "left"). Interim tab rule until 5.3: hover opens media when playing,
  else a non-empty shelf; drags always show the shelf. Tiles: Finder icon +
  name, hover-✕ removes — via an `.activeAlways` HoverSensor, since SwiftUI's
  `.onHover` is key-window-gated and the panel is never key (the 2.1 lesson
  resurfacing in SwiftUI). Combine lesson: @Published sinks fire on *willSet* —
  reading `state.presentation` inside its own sink saw the old value and
  clobbered the drag's tab; pass the sink value, read no mid-flight properties.
  Temp 4.1 menu triggers removed. ✅ verified on-device: drag-expand into shelf
  (music playing and stopped), single/multi-file drops, duplicate skipped,
  drag-away collapse, hover-✕ removal persisting across relaunch, media
  hover-priority + controls/seek/lyrics regression-free.
- [x] **4.3** Drag-out back to Finder / other apps. Each tile is a drag source
  (`.onDrag` → `NSItemProvider(contentsOf:)`, which vends a real file
  representation so the drop *copies* the file — `object: url as NSURL` would vend
  a bare URL some targets treat as an alias). The panel **tracks** the drag rather
  than freezing open: a cursor-follow tracker (started by `NotchState.isDraggingOut`
  from the `.onDrag`) collapses when the drag leaves the expanded frame and
  re-expands (to the shelf tab) when it returns — polled, since tracking areas
  don't fire over the shrunken pill mid-drag, and it runs while collapsed too so it
  can re-expand. Self-terminates on mouse-up (`.onDrag` has no end callback; a
  sticky flag got stuck open, the physical button state can't). The other collapse
  paths (hover exit, expanded watchdog) are gated on `isDraggingOut` so nothing
  fights the tracker. Shelf polish folded in during verification: the tile row
  moved into an AppKit `NSScrollView` (never-key panel → `ClickThroughHostingView`
  doc + accepts-first-mouse so tile drag/✕ still land) with a mouse-wheel→horizontal
  remap (amplified, so no Shift needed) and a **custom thin SwiftUI scrollbar** fed
  by bridged scroll geometry — SwiftUI's own indicator rendered oddly in the panel
  and a custom `NSScroller` clipped its knob; bigger Finder icons, centered block.
  ✅ verified on-device: drag-out copies into Finder **and** another app (single/
  multi type), drag / hover-✕ / scroll don't conflict, in↔out tracking is smooth
  with no stuck panel, wheel + trackpad both scroll, bar hides when the row fits.
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
- Hide-over-full-screen — attempted post-3.5, reverted after six detection
  approaches each failed on-device (notched + multi-display Mac): collection-
  behavior flags (ignored at `.statusBar` level with `canJoinAllSpaces`),
  full-frame window matching (native full screen letterboxes below the notch),
  menu-bar-level window presence (a backstop strip persists in full screen),
  `visibleFrame` (never includes the notch strip on notched Macs), wallpaper-
  window presence (culled from the on-screen list when fully covered → false
  hides on desktop), status-item occlusion (window migrates between displays'
  menu bars → spurious events). Revisit at M6 as a settings toggle built on the
  Accessibility API (focused window's `AXFullScreen` attribute — reliable, but
  needs user-granted permission).
- Collapsed-wing menu-bar overlap (3.5) — while media is loaded the widened pill
  covers ~36 pt of (normally empty) menu bar per side. Accepted for MVP; shrink
  the wings if it ever collides with real menu items.
- Lyrics — decided (3.8/3.9): LRCLIB, music-apps-only lookups, UI shipped in the
  media row. Still open: the M6 opt-out toggle, and a copyright caveat for any
  commercial release — community-transcribed lyrics are still copyrighted works;
  display-only for personal use, revisit alongside the license/paywall decision.
- Expanded-panel menu-bar overlap — while expanded the panel covers the (usually
  empty) center of the menu bar. Kept the simple overlap for now (M2.4). Options to
  revisit if it conflicts with real content: (a) **shift-down on approach** —
  temporarily slide the panel below the bar when the cursor nears it, then rise back;
  (b) **collapse on approach** — collapse the instant the cursor heads for a menu;
  (c) **island neck** — keep a notch-width neck through the menu-bar row and flare
  below it, so the bar is never covered. A first spike of (a)/(b) didn't feel right;
  they'd need refinement.
