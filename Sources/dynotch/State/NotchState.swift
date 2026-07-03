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
        case media
        case shelf
        case activities
    }

    @Published var presentation: Presentation = .collapsed
    @Published var tab: Tab = .media

    /// Shared so the AppKit frame resize and the SwiftUI content morph run on one clock.
    static let animationDuration: TimeInterval = 0.28
}
