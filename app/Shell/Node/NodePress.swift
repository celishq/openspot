import SwiftUI

struct NodePress: ViewModifier {
    let isFollowed: Bool
    let isPressed: GestureState<Bool>

    func body(content: Content) -> some View {
        if isFollowed {
            content.simultaneousGesture(DragGesture(minimumDistance: 0).updating(isPressed) { _, pressed, _ in pressed = true })
        } else {
            content
        }
    }
}
