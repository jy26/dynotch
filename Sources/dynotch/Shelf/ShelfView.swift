import AppKit
import SwiftUI

/// Drag-and-drop shelf shown in the expanded notch (Milestone 4.2). Hosted by
/// `NotchView` as one stable, opacity-gated overlay; a file drag over the panel
/// switches `NotchState.tab` to `.shelf` to reveal it. Drop-in only — drag-out
/// is 4.3, AirDrop 4.4.
struct ShelfView: View {
    @EnvironmentObject private var shelf: ShelfModel
    @EnvironmentObject private var state: NotchState

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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shelf.items, id: \.self) { url in
                    ShelfTile(url: url) { shelf.remove(url) }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)   // center tiles in the zone's height
        }
    }
}

/// One shelf file: icon + name, with a remove ✕ revealed on hover.
private struct ShelfTile: View {
    let url: URL
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
            Text(url.lastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 72)
        .padding(.vertical, 6)
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
