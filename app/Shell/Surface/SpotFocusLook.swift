import OpenspotCore
import SwiftUI

/// Brings a focused card forward and fades the rest, on the motion of a sheet.
struct SpotFocusLook: ViewModifier {
    let focus: CardFocus

    func body(content: Content) -> some View {
        content
            .scaleEffect(focus == .focused ? MotionTokens.focusedScale : 1)
            .opacity(focus == .faded ? SpotTheme.unfocused : 1)
            .animation(SpotMotion.grow(isOpen: focus != .none), value: focus)
    }
}
