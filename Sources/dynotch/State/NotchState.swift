import Combine

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

    // TODO: Milestone 2 — hover tracking drives `presentation`.
}
