import SwiftUI

extension EnvironmentValues {
    /// Whether a view lies on the solid fill of an active spot, which turns its ink to the ink of that fill.
    @Entry var spotIsOnSolid = false
}

/// Primary text and marks: the ink of the backdrop, or the ink of the solid fill that a view lies on.
struct SpotInk: ViewModifier {
    @Environment(\.spotIsOnSolid) private var isOnSolid

    func body(content: Content) -> some View {
        content.foregroundStyle(isOnSolid ? SpotTheme.onSolid : SpotTheme.ink)
    }
}
