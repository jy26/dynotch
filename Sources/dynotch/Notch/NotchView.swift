import SwiftUI

/// Root SwiftUI view hosted inside the notch panel: the collapsed pill and the
/// expanded content. Built out across Milestones 1–5.
struct NotchView: View {
    var body: some View {
        // TEMP (Milestone 1.2): tint so we can confirm the panel aligns to the notch.
        // TODO: Milestone 1.3 — black rounded pill sized to the notch;
        //       Milestones 3–5 — expanded media / shelf / activities content.
        Color.red.opacity(0.5)
    }
}
