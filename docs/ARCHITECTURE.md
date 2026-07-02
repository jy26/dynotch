# dynotch — Architecture

This document describes how dynotch is put together and the key technical
decisions. It reflects the intended design; most of it is stubbed as of
Milestone 0 and filled in across later milestones (see [ROADMAP.md](ROADMAP.md)).

## Shape of the app

dynotch is a **menu-bar agent** — no Dock icon, no main window. It uses the
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
**macOS 15.4**, so linking it directly no longer returns now-playing data. dynotch
uses the **[mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)**
approach instead:

- The system Perl binary (`/usr/bin/perl`, bundle id `com.apple.perl`) is still
  granted MediaRemote access. A bundled Perl script drives a helper framework that
  loads MediaRemote out-of-process and streams now-playing JSON to stdout.
- `MediaRemoteAdapter` spawns that script (`… stream`) via `Process`, parses the
  JSON lines into `NowPlaying` (an `@MainActor ObservableObject`), and sends
  playback commands (`send play`/`pause`/`next`/`previous`).
- Bundled artifacts (planned for Milestone 3): the Perl script and the built
  `MediaRemoteAdapter.framework`, placed in the app's Resources. Build steps will
  be documented here when that milestone lands.

**Consequence:** because this relies on a private framework, dynotch cannot ship
on the Mac App Store — distribution will be direct download / Homebrew,
code-signed and notarized.

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

When distribution work begins (Milestone 6) we may introduce an app-bundle build
(entitlements, `Info.plist`, code signing, notarization); the module layout is
independent of that choice.
