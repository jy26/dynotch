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
    private var panel: NotchPanel?
    private var frames: NotchFrames?
    private var screenObserver: NSObjectProtocol?
    private var presentationCancellable: AnyCancellable?
    private var mediaCancellable: AnyCancellable?
    /// Whether media is loaded — widens the collapsed pill into indicator wings.
    private var hasMedia = false
    /// Safety net for missed `mouseExited` events (AppKit can drop one around
    /// clicks/popovers, leaving the panel stuck expanded): while expanded, cheaply
    /// confirm the cursor is still inside; collapse if events failed us.
    private var expandedWatchdog: Timer?

    private let sendPlaybackCommand: (PlaybackCommand) -> Void
    private let sendSeek: (TimeInterval) -> Void

    /// - Parameters:
    ///   - nowPlaying: shared now-playing model, injected into the SwiftUI
    ///     environment for the expanded media UI.
    ///   - lyrics: shared lyrics service; synced lyrics grow the expanded panel.
    ///   - sendPlaybackCommand: routes control-button actions to the media
    ///     service (wired at the composition root).
    ///   - sendSeek: routes absolute-position seeks to the media service.
    init(nowPlaying: NowPlaying,
         lyrics: LyricsService,
         sendPlaybackCommand: @escaping (PlaybackCommand) -> Void,
         sendSeek: @escaping (TimeInterval) -> Void) {
        self.nowPlaying = nowPlaying
        self.lyrics = lyrics
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
                self?.applyPresentation(presentation, animated: true)
                self?.updateExpandedWatchdog(for: presentation)
            }
        // Media appearing/disappearing resizes a collapsed pill live (3.5 wings).
        mediaCancellable = nowPlaying.$title
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] hasMedia in
                guard let self else { return }
                self.hasMedia = hasMedia
                self.applyPresentation(self.state.presentation, animated: true)
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
            // Never collapse mid-scrub (3.7): the drag may cross the panel edge.
            if !hovering, self.state.isScrubbing { return }
            self.state.presentation = hovering ? .expanded : .collapsed
        }
        // ClickThroughHostingView: the panel is never key, so button clicks
        // arrive as "first mouse" and need the accepts-first-mouse opt-in.
        let hosting = ClickThroughHostingView(rootView: NotchView()
            .environmentObject(state)
            .environmentObject(nowPlaying)
            .environmentObject(lyrics)
            .environment(\.sendPlaybackCommand, sendPlaybackCommand)
            .environment(\.sendSeek, sendSeek))
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)

        panel.contentView = container
        self.panel = panel
        return panel
    }

    private func updateExpandedWatchdog(for presentation: NotchState.Presentation) {
        expandedWatchdog?.invalidate()
        expandedWatchdog = nil
        guard presentation == .expanded else { return }
        expandedWatchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let frames = self.frames else { return }
                guard !self.state.isScrubbing else { return }   // never collapse mid-scrub (3.7)
                // Same tolerance as the container's exit guard (top-edge quirk).
                if !frames.expanded.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                    self.state.presentation = .collapsed
                }
            }
        }
    }

    deinit {
        expandedWatchdog?.invalidate()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
