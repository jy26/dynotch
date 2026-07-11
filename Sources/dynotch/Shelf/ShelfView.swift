import AppKit
import SwiftUI

/// Drag-and-drop shelf shown in the expanded notch (Milestone 4). Hosted by
/// `NotchView` as one stable, opacity-gated overlay; a file drag over the panel
/// switches `NotchState.tab` to `.shelf` to reveal it. Drop-in (4.2), drag-out
/// (4.3, `.onDrag` per tile), and share/AirDrop (4.4, a per-tile hover button →
/// `NSSharingServicePicker`) are all wired up.
struct ShelfView: View {
    @EnvironmentObject private var shelf: ShelfModel
    @EnvironmentObject private var state: NotchState

    // Scroll geometry bridged out of the AppKit scroller to drive the custom bar.
    @State private var scrollX: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                emptyState
            } else {
                tiles
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // Drop-zone highlight while a file drag hovers the panel.
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(state.isFileDragTargeted ? 0.5 : 0),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        .padding(.top, 40)            // clears the hardware-notch strip (32–38 pt)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
        .animation(.easeOut(duration: 0.15), value: state.isFileDragTargeted)
        .animation(.easeOut(duration: 0.2), value: shelf.items)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.55))
            Text("Drop files here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tiles: some View {
        VStack(spacing: 6) {
            TileScroller(urls: shelf.items,
                         onDragStart: { state.isDraggingOut = true },
                         onRemove: { shelf.remove($0) },
                         onSharing: { state.isSharing = $0 },
                         onMetrics: { x, content, viewport in
                             scrollX = x; contentWidth = content; viewportWidth = viewport
                         })
                .frame(height: 84)
            scrollBar
        }
        // Center the tiles + bar as one block in the zone.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Thin custom scrollbar (the native `NSScroller` is hidden): a translucent
    /// capsule sized by the visible fraction and positioned by the scroll offset,
    /// hidden entirely when the tiles don't overflow.
    private var scrollBar: some View {
        GeometryReader { geo in
            let track = geo.size.width
            let overflow = max(0, contentWidth - viewportWidth)
            let ratio = contentWidth > 0 ? min(1, viewportWidth / contentWidth) : 1
            let thumb = max(24, track * ratio)
            let fraction = overflow > 0 ? scrollX / overflow : 0
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: thumb, height: 3)
                .position(x: thumb / 2 + (track - thumb) * fraction, y: geo.size.height / 2)
                .opacity(ratio < 1 ? 1 : 0)
        }
        .frame(height: 3)
        .padding(.horizontal, 14)
    }
}

/// One shelf file: icon + name, with a remove ✕ revealed on hover.
private struct ShelfTile: View {
    let url: URL
    let onDragStart: () -> Void
    let onRemove: () -> Void
    /// Called `true` when this tile's share sheet opens and `false` when it closes.
    let onSharing: (Bool) -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 50, height: 50)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 90)   // room for the hover controls to flank the icon, not sit on it
        .padding(.vertical, 6)
        .onDrag {
            onDragStart()   // controller then tracks the drag: collapse out, expand back in
            // `contentsOf:` vends a real file representation (correct UTI) so Finder /
            // Mail / editors copy the actual file; `object: url as NSURL` would vend a
            // bare URL some targets treat as an alias — that's the fallback.
            return NSItemProvider(contentsOf: url) ?? NSItemProvider()
        }
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white.opacity(0.9), .black.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        // Persistent (not `if hovering`): the share popover anchors to this view and
        // must survive the cursor leaving the tile — the icon just gates on hover.
        .overlay(alignment: .topLeading) {
            ShareButton(url: url, hovered: hovering, onSharing: onSharing)
                .frame(width: 18, height: 18)
        }
        .background(HoverSensor { hovering = $0 })
    }
}

/// `.onHover` never fires in the notch panel — SwiftUI's tracking is
/// key-window-gated and the panel is never key (the 2.1 lesson: only
/// `.activeAlways` tracking areas work here). A click-transparent sensor view
/// with an always-active tracking area supplies hover instead.
private struct HoverSensor: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> SensorView {
        let view = SensorView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: SensorView, context: Context) {
        view.onChange = onChange
    }

    final class SensorView: NSView {
        var onChange: ((Bool) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(
                rect: .zero,                       // ignored under .inVisibleRect
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
        }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }
        // Tracking areas are geometric — hit-testing isn't needed, and a nil
        // hit test keeps the sensor from stealing clicks (or 4.3's tile drags).
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// Horizontal tile scroller backed by AppKit. SwiftUI's `ScrollView` indicator
/// renders oddly in the never-key notch panel and its thickness can't be styled,
/// so the tile row lives in an `NSScrollView` with the native scroller hidden — a
/// thin custom SwiftUI bar (see `ShelfView.scrollBar`) is drawn instead, fed by the
/// scroll geometry reported through `onMetrics`. The mouse wheel is remapped to
/// horizontal so scrolling needs no Shift. Tiles need no environment — just the URL
/// and two callbacks — so plain values cross the AppKit boundary. The document view
/// is a `ClickThroughHostingView` (and the scroll view accepts first mouse) because
/// the panel is never key, so a tile click/drag arrives as a first-mouse event —
/// the 4.2 lesson, one level down.
private struct TileScroller: NSViewRepresentable {
    let urls: [URL]
    let onDragStart: () -> Void
    let onRemove: (URL) -> Void
    /// Called `true`/`false` as any tile's share sheet opens/closes.
    let onSharing: (Bool) -> Void
    /// Reports (scroll offset x, content width, viewport width) whenever they change.
    let onMetrics: (CGFloat, CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMetrics: onMetrics) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = HorizontalTileScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false   // custom SwiftUI bar draws it instead
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .allowed
        scroll.verticalScrollElasticity = .none
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentView.postsBoundsChangedNotifications = true

        let hosting = ClickThroughHostingView(rootView: row)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: scroll.contentView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            hosting.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
        ])
        context.coordinator.attach(to: scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        (scroll.documentView as? ClickThroughHostingView<AnyView>)?.rootView = row
        context.coordinator.onMetrics = onMetrics
        context.coordinator.reportLater(scroll)   // content width may have changed
    }

    private var row: AnyView {
        AnyView(
            HStack(spacing: 10) {
                ForEach(urls, id: \.self) { url in
                    ShelfTile(url: url,
                              onDragStart: onDragStart,
                              onRemove: { onRemove(url) },
                              onSharing: onSharing)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)   // center the row within the strip height
        )
    }

    /// Watches the clip view's bounds so the custom scrollbar tracks live scrolling
    /// and content changes; reports on the main queue (SwiftUI @State).
    final class Coordinator {
        var onMetrics: (CGFloat, CGFloat, CGFloat) -> Void
        private var observer: NSObjectProtocol?

        init(onMetrics: @escaping (CGFloat, CGFloat, CGFloat) -> Void) {
            self.onMetrics = onMetrics
        }

        func attach(to scroll: NSScrollView) {
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scroll.contentView,
                queue: .main
            ) { [weak self, weak scroll] _ in
                guard let scroll else { return }
                self?.report(scroll)
            }
            reportLater(scroll)   // initial size (after first layout)
        }

        func reportLater(_ scroll: NSScrollView) {
            DispatchQueue.main.async { [weak self, weak scroll] in
                guard let scroll else { return }
                self?.report(scroll)
            }
        }

        private func report(_ scroll: NSScrollView) {
            let clip = scroll.contentView
            onMetrics(clip.bounds.origin.x, scroll.documentView?.frame.width ?? 0, clip.bounds.width)
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}

/// `NSScrollView` that scrolls horizontally from a vertical mouse wheel (so the
/// shelf scrolls without holding Shift); trackpad horizontal swipes already carry
/// `scrollingDeltaX` and pass straight through. Accepts first mouse so tile
/// clicks/drags land in the never-key panel.
private final class HorizontalTileScrollView: NSScrollView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard event.scrollingDeltaX == 0, event.scrollingDeltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }
        let clip = contentView
        let maxX = max(0, (documentView?.frame.width ?? 0) - clip.bounds.width)
        // Precise (trackpad) deltas are already in points; mouse-wheel line deltas
        // are tiny (~1–3), so amplify them or a full notch barely moves the shelf.
        let step = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY
                                                    : event.scrollingDeltaY * 16
        let x = min(max(0, clip.bounds.origin.x - step), maxX)
        clip.scroll(to: NSPoint(x: x, y: clip.bounds.origin.y))
        reflectScrolledClipView(clip)
    }
}

/// The per-tile "share" affordance (4.4). AppKit rather than a SwiftUI `Button`
/// like the ✕ on purpose: `NSSharingServicePicker` shows a popover that anchors to
/// an `NSView`, and that anchor must persist while the popover is open — a SwiftUI
/// `if hovering { … }` button would vanish the instant the cursor leaves the tile
/// for the popover. So this view is always in the layout (the icon merely gates on
/// hover) and presents the picker relative to *itself*, sidestepping any
/// coordinate plumbing across the nested SwiftUI/AppKit boundary.
private struct ShareButton: NSViewRepresentable {
    let url: URL
    let hovered: Bool
    let onSharing: (Bool) -> Void

    func makeNSView(context: Context) -> ShareButtonView {
        let view = ShareButtonView()
        view.url = url
        view.onSharing = onSharing
        view.hovered = hovered
        return view
    }

    func updateNSView(_ view: ShareButtonView, context: Context) {
        view.url = url
        view.onSharing = onSharing
        view.hovered = hovered
    }
}

final class ShareButtonView: NSView, NSSharingServicePickerDelegate {
    var url: URL?
    var onSharing: ((Bool) -> Void)?
    var hovered = false { didSet { icon.isHidden = !hovered } }

    private let icon = NSImageView()
    private var picker: NSSharingServicePicker?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        icon.image = NSImage(systemSymbolName: "square.and.arrow.up",
                             accessibilityDescription: "Share")?.withSymbolConfiguration(config)
        icon.contentTintColor = .white
        icon.isHidden = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // Never-key panel → clicks arrive as first mouse (the 2.1 / 4.2 lesson).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Only intercept while the icon is shown; otherwise transparent, so a drag or
    // click starting in this corner still reaches the tile (the HoverSensor lesson).
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hovered else { return nil }
        return super.hitTest(point) != nil ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        guard let url else { return }
        onSharing?(true)
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        self.picker = picker
        // The panel hugs the top of the screen, so point the popover downward
        // (`.minY` — this view isn't flipped) where there's room; `.maxY` aimed it
        // into the sliver above the notch and the sheet got squeezed small.
        picker.show(relativeTo: bounds, of: self, preferredEdge: .minY)
    }

    // Fires with the chosen service, or nil when dismissed — either way the popover
    // is gone, so release the suppression flag and drop the retained picker.
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              didChoose service: NSSharingService?) {
        onSharing?(false)
        picker = nil
    }
}
