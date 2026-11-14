import SwiftUI

struct FlowArrival: ViewModifier {
    var scale = 1.0
    var shift: CGFloat = 0
    var opacity = 1.0
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .offset(x: shift)
            .opacity(opacity)
    }
}
