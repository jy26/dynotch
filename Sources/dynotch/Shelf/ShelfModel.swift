import Foundation
import Combine

/// Holds files the user has dropped into the notch shelf, persisted as
/// security-scoped bookmarks. Implemented in Milestone 4.
@MainActor
final class ShelfModel: ObservableObject {
    @Published private(set) var items: [URL] = []

    // TODO: Milestone 4 — add/remove with security-scoped bookmarks + persistence.
}
