import Combine
import Foundation

/// Presentation state of the notch surface.
///
/// Drives the collapsed ↔ expanded transition (Milestone 2) and which panel is
/// shown when the notch is expanded (Milestone 5's tab system).
@MainActor
final class NotchState: ObservableObject {
    enum Presentation {
        case collapsed
        case expanded
    }

    enum Tab {
        case home
        case media
        case shelf
        case activities
    }

    @Published var presentation: Presentation = .collapsed
    @Published var tab: Tab = .home
    /// True while the user is dragging the progress bar (3.7). The collapse paths
    /// (hover exit, expanded watchdog) are suppressed so the panel can't fold
    /// mid-drag when the cursor crosses its edge.
    @Published var isScrubbing = false
    /// True while a file drag hovers the panel (4.2). Expands the panel (tracking
    /// areas don't fire mid-drag, so hover can't), highlights the drop zone, and
    /// suppresses the collapse paths like `isScrubbing`.
    @Published var isFileDragTargeted = false
    /// True while the user drags a shelf tile *out* of the panel (4.3). Starts a
    /// cursor-following tracker in the controller so the panel tracks the drag —
    /// collapse when it leaves, re-expand when it returns. Runs even while collapsed
    /// (tracking areas don't fire over the shrunken pill mid-drag) and is cleared
    /// when the mouse button is released (`.onDrag` has no drag-end callback).
    @Published var isDraggingOut = false
    /// True while a tile's share sheet (`NSSharingServicePicker`) is open (4.4).
    /// The popover anchors to a view inside the panel and the cursor leaves the
    /// panel to reach it, so — like the drag flags — the collapse paths are
    /// suppressed to keep the panel (and the anchor) put until the sheet closes.
    @Published var isSharing = false
    /// True while the timer's duration text field is focused (5.x). Keyboard editing
    /// needs the panel key, and the cursor may leave the panel — suppress the
    /// collapse paths so it can't fold mid-edit.
    @Published var isEditingTimer = false
    /// Collapsed (notch-hugging) pill size for the current screen; set by the
    /// controller on placement. Collapsed content pins itself to this strip.
    @Published var collapsedSize: CGSize = .zero

    /// Shared so the AppKit frame resize and the SwiftUI content morph run on one clock.
    static let animationDuration: TimeInterval = 0.28
}
