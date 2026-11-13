import SwiftUI

/// A SwiftUI view in a menu bar item, which leaves each click to the button that holds it.
final class MenuBarHost<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
