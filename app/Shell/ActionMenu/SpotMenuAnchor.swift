import SwiftUI

/// The selected item that the actions menu opens at: its edge, and the radius of its corners.
struct SpotMenuAnchor: PreferenceKey {
    struct Item {
        let bounds: Anchor<CGRect>
        let corner: CGFloat
    }

    static var defaultValue: Item? { nil }

    static func reduce(value: inout Item?, nextValue: () -> Item?) {
        value = nextValue() ?? value
    }
}
