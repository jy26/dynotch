import AppKit
import Combine
import SwiftUI

/// Creates the `NotchPanel`, positions it over the notch, and keeps it in sync
/// with live display changes (dock/undock, clamshell open/close, resolution).
///
/// Milestone 1 positions the panel over the notch and shows/hides it as displays
/// come and go; Milestone 2 adds hover-driven resize between the collapsed and
/// expanded frames.
@MainActor
final class NotchWindowController {
    private let state = NotchState()
    private let nowPlaying: NowPlaying
    private let lyrics: LyricsService
    private let shelf: ShelfModel
    private var panel: NotchPanel?
    private var frames: NotchFrames?
    private var screenObserver: NSObjectProtocol?
    private var presentationCancellable: AnyCancellable?
    private var mediaCancellable: AnyCancellable?
    private var dragCancellable: AnyCancellable?
    /// Whether media is loaded — widens the collapsed pill into indicator wings.
    private var hasMedia = false
    /// Safety net for missed `mouseExited` events (AppKit can drop one around
    /// clicks/popovers, leaving the panel stuck expanded): while expanded, cheaply
    /// confirm the cursor is still inside; collapse if events failed us.
    private var expandedWatchdog: Timer?
    /// Follows the cursor while a shelf tile is dragged out (4.3) so the panel tracks
    /// the drag. Runs regardless of presentation (unlike the watchdog, which only runs
    /// while expanded) and self-terminates when the mouse button is released.
    private var dragTracker: Timer?

    private let sendPlaybackCommand: (PlaybackCommand) -> Void
    private let sendSeek: (TimeInterval) -> Void

    /// - Parameters:
    ///   - nowPlaying: shared now-playing model, injected into the SwiftUI
    ///     environment for the expanded media UI.
    ///   - lyrics: shared lyrics service; synced lyrics grow the expanded panel.
    ///   - shelf: shared shelf model; file drags over the panel drop into it.
    ///   - sendPlaybackCommand: routes control-button actions to the media
    ///     service (wired at the composition root).
    ///   - sendSeek: routes absolute-position seeks to the media service.
    init(nowPlaying: NowPlaying,
         lyrics: LyricsService,
         shelf: ShelfModel,
         sendPlaybackCommand: @escaping (PlaybackCommand) -> Void,
         sendSeek: @escaping (TimeInterval) -> Void) {
        self.nowPlaying = nowPlaying
        self.lyrics = lyrics
        self.shelf = shelf
        self.sendPlaybackCommand = sendPlaybackCommand
        self.sendSeek = sendSeek
    }

    /// Places the panel over the notch (if any) and starts observing display
    /// changes so it repositions / shows / hides live. Call once at launch.
    func start() {
        guard screenObserver == nil else { return }   // idempotent: safe to call once
        updatePlacement()
        presentationCancellable = state.$presentation
            .removeDuplicates()
            .sink { [weak self] presentation in
                guard let self else { return }
                self.applyPresentation(presentation, animated: true)
                self.updateExpandedWatchdog(for: presentation)
                self.resetDefaultTab(for: presentation)
            }
        // A tile drag-out (4.3) starts the cursor tracker. Use the emitted value —
        // reading `state.isDraggingOut` here would see the pre-`willSet` value.
        dragCancellable = state.$isDraggingOut
            .removeDuplicates()
            .sink { [weak self] dragging in
                if dragging { self?.startDragTracker() }
            }
        // Media appearing/disappearing resizes a collapsed pill live (3.5 wings).
        mediaCancellable = nowPlaying.$title
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] hasMedia in
                guard let self else { return }
                self.hasMedia = hasMedia
                self.applyPresentation(self.state.presentation, animated: true)
                // Media arriving/leaving changes which tab the next expand shows.
                // (Safe property read: this sink is triggered by the title, not
                // by `presentation`, so `state.presentation` is settled here.)
                self.resetDefaultTab(for: self.state.presentation)
            }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delivered on `.main`, so we're already on the main actor.
            MainActor.assumeIsolated { self?.updatePlacement() }
        }
    }

    /// Idempotent: shows + positions the panel over the current notch, or hides
    /// it when no notched display is present. Safe to call repeatedly.
    private func updatePlacement() {
        guard let screen = ScreenGeometry.notchedScreen(),
              let notch = ScreenGeometry.notchRect(for: screen) else {
            panel?.orderOut(nil)          // no notch → hide cleanly, keep for reuse
            return
        }
        let panel = ensurePanel()
        frames = ScreenGeometry.frames(for: screen, collapsed: notch)
        state.collapsedSize = notch.size       // collapsed content pins to this strip
        applyPresentation(state.presentation, animated: false)   // reposition for the new frames
        panel.orderFrontRegardless()           // show without activating the app
    }

    /// Sizes the panel to the collapsed or expanded frame, animating the resize on
    /// hover transitions and snapping instantly on display changes. AppKit owns the
    /// frame animation; SwiftUI just fills whatever bounds it's given.
    private func applyPresentation(_ presentation: NotchState.Presentation, animated: Bool) {
        guard let panel, let frames else { return }
        let target = (presentation == .expanded) ? frames.expanded
                                                 : frames.collapsed(hasMedia: hasMedia)
        guard panel.frame != target else { return }   // no-op / re-entrancy guard
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = NotchState.animationDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                panel.animator().setFrame(target, display: true)
            }
        } else {
            panel.setFrame(target, display: true)
        }
    }

    /// Lazily builds the reusable panel: a hover-tracking container hosting the
    /// SwiftUI content. Hover drives `state.presentation`.
    private func ensurePanel() -> NotchPanel {
        if let panel { return panel }
        let panel = NotchPanel(contentRect: .zero)   // setFrame supplies the rect

        let container = NotchContainerView()
        container.onHoverChange = { [weak self] hovering in
            guard let self else { return }
            // Never collapse mid-scrub (3.7) or mid-file-drag (4.2): the drag
            // may cross the panel edge. Mid-drag-out (4.3) the tracker owns the panel.
            if !hovering, self.state.isScrubbing || self.state.isFileDragTargeted
                || self.state.isDraggingOut { return }
            self.state.presentation = hovering ? .expanded : .collapsed
        }
        container.onFileDragChange = { [weak self] targeted in
            guard let self else { return }
            self.state.isFileDragTargeted = targeted
            if targeted {
                self.state.tab = .shelf
                self.state.presentation = .expanded
            } else if let frames = self.frames,
                      !frames.expanded.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                // `false` also fires (via draggingEnded) after a drop, with the
                // cursor still inside — stay expanded then; the hover machinery
                // and watchdog own the collapse from here. Only a drag that
                // really left the panel collapses it.
                self.state.presentation = .collapsed
            }
        }
        container.onFileDrop = { [weak self] urls in
            self?.shelf.add(urls)
        }
        // ClickThroughHostingView: the panel is never key, so button clicks
        // arrive as "first mouse" and need the accepts-first-mouse opt-in.
        let hosting = ClickThroughHostingView(rootView: NotchView()
            .environmentObject(state)
            .environmentObject(nowPlaying)
            .environmentObject(lyrics)
            .environmentObject(shelf)
            .environment(\.sendPlaybackCommand, sendPlaybackCommand)
            .environment(\.sendSeek, sendSeek))
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)

        panel.contentView = container
        self.panel = panel
        return panel
    }

    /// Interim rule until M5.3's tab system: the next expand shows media when
    /// something is playing; otherwise a non-empty shelf — hover is the shelf's
    /// only free-cursor path (mid-drag the cursor can't click the ✕).
    ///
    /// `presentation` is a parameter, and media presence comes from the settled
    /// `hasMedia`, on purpose: @Published sinks fire on *willSet*, so reading
    /// `state.presentation` (or `nowPlaying.title`) from inside their own sinks
    /// sees the OLD value — doing so here clobbered the drag's `.shelf` tab.
    private func resetDefaultTab(for presentation: NotchState.Presentation) {
        guard presentation == .collapsed else { return }
        state.tab = (!hasMedia && !shelf.items.isEmpty) ? .shelf : .media
    }

    private func updateExpandedWatchdog(for presentation: NotchState.Presentation) {
        expandedWatchdog?.invalidate()
        expandedWatchdog = nil
        guard presentation == .expanded else { return }
        expandedWatchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let frames = self.frames else { return }
                // Never collapse mid-scrub (3.7), mid-file-drag (4.2), or mid-drag-out
                // (4.3) — the drag tracker owns the panel during a tile drag-out.
                guard !self.state.isScrubbing, !self.state.isFileDragTargeted,
                      !self.state.isDraggingOut else { return }
                // Same tolerance as the container's exit guard (top-edge quirk).
                if !frames.expanded.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                    self.state.presentation = .collapsed
                }
            }
        }
    }

    /// While a shelf tile is being dragged out (4.3), follow the cursor so the panel
    /// tracks the drag: collapse when the drag leaves the expanded frame, re-expand
    /// (back to the shelf tab) when it returns. Polls rather than leaning on tracking
    /// areas, which don't fire over the shrunken pill mid-drag, and runs while
    /// collapsed too so it can re-expand. Self-terminates on mouse-up — `.onDrag`
    /// has no drag-end callback, and the physical button state can't get stuck.
    private func startDragTracker() {
        dragTracker?.invalidate()
        dragTracker = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if NSEvent.pressedMouseButtons & 0x1 == 0 {   // button released → drag over
                    self.dragTracker?.invalidate()
                    self.dragTracker = nil
                    self.state.isDraggingOut = false           // hover/watchdog resume
                    return
                }
                guard let frames = self.frames else { return }
                if frames.expanded.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                    if self.state.tab != .shelf { self.state.tab = .shelf }
                    self.state.presentation = .expanded        // deduped by the sink
                } else {
                    self.state.presentation = .collapsed
                }
            }
        }
    }

    deinit {
        expandedWatchdog?.invalidate()
        dragTracker?.invalidate()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
