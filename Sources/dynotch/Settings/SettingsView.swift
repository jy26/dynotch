import SwiftUI

/// Preferences UI. Fleshed out in Milestone 6 (@AppStorage-backed prefs).
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("dynotch")
                .font(.headline)
            Text("Settings coming in a later milestone.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360, height: 160)
        // TODO: Milestone 6 — real settings backed by @AppStorage.
    }
}
