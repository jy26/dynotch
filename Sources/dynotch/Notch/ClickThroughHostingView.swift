import AppKit
import SwiftUI

/// NSHostingView that accepts the "first mouse". The notch panel is borderless
/// and never key, so EVERY click arrives as a first mouse; with the NSView
/// default (false) AppKit swallows clicks instead of delivering them to the
/// SwiftUI controls. Plain SwiftUI Buttons hit-test to the hosting view itself,
/// so this override is the one that gets consulted.
final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
