import OpenspotCore
import SwiftUI

struct SpotFocusLook: ViewModifier {
    let focus: CardFocus

    func body(content: Content) -> some View {
        content
            .scaleEffect(focus == .focused ? MotionTokens.focusedScale : 1)
            .opacity(focus == .faded ? SpotTheme.unfocusedCardStrength : 1)
            .animation(SpotMotion.grow(isOpen: focus != .none), value: focus)
    }
}
