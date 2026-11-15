import SwiftUI

struct SpotHover<S: Shape>: ViewModifier {
    let isOnSolid: Bool
    let shape: S
    @State private var isOver = false

    func body(content: Content) -> some View {
        content
            .overlay {
                shape.fill((isOnSolid ? SpotTheme.onSolid : SpotTheme.ink).opacity(isOver ? SpotTheme.hover : 0)).allowsHitTesting(false)
            }
            .onHover { isOver = $0 }
    }
}

extension View {
    func spotHover(isOnSolid: Bool = false, in shape: some Shape) -> some View {
        modifier(SpotHover(isOnSolid: isOnSolid, shape: shape))
    }
}
