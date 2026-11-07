import SwiftUI

/// A width that lays its words out again on each frame of a motion, so that a line truncates at the moving edge.
struct SpotWordsWidth: ViewModifier, @preconcurrency Animatable {
    var width: CGFloat

    var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }

    func body(content: Content) -> some View {
        content.frame(width: max(width, 0), alignment: .leading)
    }
}
