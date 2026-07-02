# dyNotch

**dyNotch** — a **DY**namic **NOTCH** for your Mac. It turns the MacBook's
hardware notch into an interactive surface for media, files, and glanceable live
activities, in the spirit of [NotchNook](https://lo.cafe/notchnook),
[Alcove](https://tryalcove.com), and the open-source
[Boring Notch](https://github.com/TheBoredTeam/boring.notch).

> **Status: early WIP.** Milestone 0 (the project framework) is complete: the app
> builds and runs as a menu-bar agent, with the module layout stubbed out. No
> notch UI, media, shelf, or activities are implemented yet — see
> [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Target

- **macOS 14 Sonoma or later**, on notched MacBooks (14"/16"). Degrades gracefully
  on external / non-notched displays.
- Native **Swift** — SwiftUI for UI, AppKit (`NSPanel`) for the notch window.

## Planned MVP features

- **Media & now-playing** — expandable player with artwork, track info, live
  progress, and play/pause/skip controls.
- **File shelf** — a drag-and-drop tray in the notch that holds files, with AirDrop.
- **Live activities** — glanceable idle indicators (charging/battery, timers).

HUD replacement (volume/brightness) is planned as an optional later phase.

## Build & run

Requires a Swift toolchain (full Xcode, or Xcode Command Line Tools):

```sh
swift build      # compile
swift run        # launch the menu-bar agent
```

When it runs you should see a **menu-bar icon** and **no Dock icon**; the menu's
**Quit** item exits the app.

To work in Xcode (requires full Xcode installed), open the package directly:

```sh
open Package.swift
```

## Project layout

```
Package.swift                 # SwiftPM manifest (macOS 14+, executable target)
Sources/dynotch/
├── DynotchApp.swift          # @main App + NSApplicationDelegateAdaptor
├── App/AppDelegate.swift     # menu-bar status item; owns the notch panel (later)
├── Notch/                    # NotchPanel, NotchWindowController, ScreenGeometry, NotchView
├── Media/                    # MediaRemoteAdapter, NowPlaying
├── Shelf/                    # ShelfModel, ShelfView
├── Activities/               # ActivityModel, ActivityView
├── State/NotchState.swift    # collapsed/expanded + active tab
└── Settings/SettingsView.swift
docs/
├── ARCHITECTURE.md           # how it's put together
└── ROADMAP.md                # milestone-by-milestone plan
```

Lowercase `dynotch` is the slug — used for the repo, the local folder, the
`Sources/dynotch/` path, and the built executable. **dyNotch** is the display name.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — the window model, notch geometry, and
  media-adapter approach.
- [Roadmap](docs/ROADMAP.md) — the incremental milestone plan.
- [Branding](docs/BRANDING.md) — the dyNotch name and the DYnoTCH logo concept.

## Acknowledgements

- [TheBoringNotch/boring.notch](https://github.com/TheBoredTeam/boring.notch) — the
  primary open-source reference.
- [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) (BSD-3)
  — the mechanism that keeps now-playing working on macOS 15.4+.

## License

**To be decided** — see [`LICENSE`](LICENSE). The one planned third-party
dependency (mediaremote-adapter) is BSD-3, which is compatible with either an
open-source or a commercial release.
