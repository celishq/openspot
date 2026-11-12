import OpenspotCore
import SwiftUI

/// Brings a focused card forward and fades the rest, on the motion of a sheet.
struct SpotFocusLook: ViewModifier {
    let focus: CardFocus

    func body(content: Content) -> some View {
        content
            .scaleEffect(focus == .focused ? SpotMotion.focusedScale : 1)
            .opacity(focus == .faded ? SpotTheme.unfocused : 1)
            .animation(SpotMotion.sheet(isOpen: focus != .none), value: focus)
    }
}
