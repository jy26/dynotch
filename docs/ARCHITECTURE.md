# dyNotch — Architecture

This document describes how dyNotch is put together and the key technical
decisions. It reflects the intended design; most of it is stubbed as of
Milestone 0 and filled in across later milestones (see [ROADMAP.md](ROADMAP.md)).

## Shape of the app

dyNotch is a **menu-bar agent** — no Dock icon, no main window. It uses the
SwiftUI `App` lifecycle with an `NSApplicationDelegateAdaptor`:

- `DynotchApp` (`@main`) declares a `Settings` scene (preferences) and installs
  the app delegate. There is intentionally no `WindowGroup`.
- `AppDelegate` sets the activation policy to `.accessory` (hides the Dock icon),
  installs the menu-bar `NSStatusItem`, and — from Milestone 1 — owns the notch
  panel.

The notch itself is **not** a normal window. It is a borderless AppKit panel that
floats above everything and hosts SwiftUI content.

## The notch window

The notch surface is an `NSPanel` (`NotchPanel`) configured as:

- `styleMask = [.borderless, .nonactivatingPanel]` — no title bar/chrome, and it
  never steals key focus from the app you're working in.
- `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false` — so the
  drawn black pill can match the physical notch exactly.
- `level = .statusBar` (raised toward `.mainMenu + 1` if it must sit above the
  menu bar).
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`
  — visible on every Space and over full-screen apps.
- Content hosted via an `NSHostingView` wrapping `NotchView` (SwiftUI).

`NotchWindowController` positions the panel over the notch and, on hover, animates
its frame between the **collapsed** (≈ notch-sized) and **expanded** (larger)
states. The panel is deliberately larger than the physical notch when expanded so
it can catch hover and draw content below the notch; it resizes dynamically so the
rest of the menu bar stays click-through.

## Notch geometry

`ScreenGeometry` derives the notch rectangle from `NSScreen`:

- `safeAreaInsets.top` → notch **height**.
- `frame.width − auxiliaryTopLeftArea.width − auxiliaryTopRightArea.width` →
  notch **width** (the two auxiliary areas are the menu-bar strips flanking the
  notch).
- `safeAreaInsets.top == 0` → the display has no notch; render a top-center
  fallback pill or hide, so the app still works on external / non-notched Macs.

## Now-playing (the hard part)

The private `MediaRemote` framework was locked behind an entitlement check in
**macOS 15.4**, so linking it directly no longer returns now-playing data. dyNotch
uses the **mediaremote-adapter** approach instead: the system Perl binary
(`/usr/bin/perl`, bundle id `com.apple.perl`) is still granted MediaRemote access,
so a Perl script loads a small adapter library **out-of-process** and streams
now-playing JSON to stdout; dyNotch only reads that stdout and never loads
MediaRemote itself.

**Dependency.** The canonical repo is
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
(BSD-3), but it ships source-only and its framework build requires CMake — which
the Command-Line-Tools-only constraint rules out. dyNotch instead depends on the
**[ejbills/mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter)**
SwiftPM fork (endorsed by upstream's README), **pinned by revision** in
`Package.swift`: the fork has no version tags, and SwiftPM only accepts its
`unsafeFlags` (`-fno-objc-arc`) from revision/branch/local dependencies. Updates
are deliberate SHA bumps after testing. Attribution lives in
[THIRD-PARTY.md](THIRD-PARTY.md).

**Build step.** `swift build` is the entire build step: the package compiles the
ObjC adapter (`CIMediaRemote`) into the dynamic product
`libMediaRemoteAdapter.dylib` and copies `run.pl` into the resource bundle
`MediaRemoteAdapter_MediaRemoteAdapter.bundle`, both next to the executable
(`.build/<triple>/debug/` under `swift run`). Toolchain note: SwiftPM honors the
`CC` environment variable for C-family targets — if the shell exports a GNU gcc
(e.g. Homebrew `CC=gcc-15`), the ObjC target fails on clang-only flags; build with
`CC=clang swift build` or unset `CC`.

**Runtime chain.** dyNotch spawns
`/usr/bin/perl run.pl <dylib-path> loop` (streaming; `get` for one-shots); perl
DynaLoader-loads the dylib and emits single-line JSON
(`{"type":"data","payload":{…}}`). `MediaRemoteAdapterService` parses those lines
into `NowPlaying` (an `@MainActor ObservableObject`) and sends playback commands
by writing newline-delimited lines to the loop's **stdin** (`play` / `pause` /
`toggle_play_pause` / `next_track` / `previous_track`) — fire-and-forget; state
comes back via the stream. UI note: the notch panel is never key, so button
clicks arrive as "first mouse" — `ClickThroughHostingView` opts in via
`acceptsFirstMouse`, which delivers clicks to the SwiftUI controls without any
key-status change (no focus theft).

**Path caveat (why we own the spawn).** The fork's own Swift API
(`MediaController`) resolves the dylib via `Bundle(for:).executablePath`, which
only works inside an `.app` bundle with the product embedded as a framework.
Under bare `swift run` it resolves to our executable and fails — so dyNotch
locates the dylib and `run.pl` itself and owns the `Process` spawn layer.

**Milestone 6 notes.** When the app-bundle build lands: embed
`libMediaRemoteAdapter.dylib` in `Contents/Frameworks` and the resource bundle in
`Contents/Resources`, and sign the dylib with the app's identity. Notarization is
expected to pass — the private framework is only loaded inside the perl child
process. **Consequence:** because this relies on a private framework, dyNotch
cannot ship on the Mac App Store — distribution will be direct download /
Homebrew, code-signed and notarized.

## Module map

| Module | Type(s) | Responsibility |
|---|---|---|
| `App` | `DynotchApp`, `AppDelegate` | lifecycle, menu-bar item, owns the notch panel |
| `Notch` | `NotchPanel`, `NotchWindowController`, `ScreenGeometry`, `NotchView` | the floating notch window, its geometry and SwiftUI content |
| `Media` | `MediaRemoteAdapter`, `NowPlaying` | now-playing data + playback control |
| `Shelf` | `ShelfModel`, `ShelfView` | drag-and-drop file tray (security-scoped bookmarks) |
| `Activities` | `ActivityModel`, `ActivityView` | glanceable live activities (battery, timers) |
| `State` | `NotchState` | collapsed/expanded + active tab |
| `Settings` | `SettingsView` | preferences UI |

## Why Swift Package Manager (for now)

The project is scaffolded as a **Swift Package** rather than an `.xcodeproj`
because it builds with just the Xcode **Command Line Tools** (`swift build` /
`swift run`) — no full Xcode required — and Xcode opens `Package.swift` natively
when you want an IDE. The menu-bar-agent behavior (no Dock icon) is set in code
via `NSApp.setActivationPolicy(.accessory)`, so no `Info.plist`/`LSUIElement` is
needed at this stage.

Code-level identifiers stay lowercase `dynotch` — the SwiftPM product/executable,
the source directory (`Sources/dynotch/`), and the repo slug. **dyNotch** is the
display name used in the UI and docs.

When distribution work begins (Milestone 6) we may introduce an app-bundle build
(entitlements, `Info.plist`, code signing, notarization); the module layout is
independent of that choice.
