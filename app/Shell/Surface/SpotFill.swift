import SwiftUI

struct SpotFill<S: Shape>: ViewModifier {
    let isActive: Bool
    let otherwise: Color
    let shape: S

    func body(content: Content) -> some View {
        content
            .modifier(SpotInk())
            .background(isActive ? SpotTheme.solid : otherwise, in: shape)
            .environment(\.spotIsOnSolid, isActive)
    }
}

extension View {
    func spotFill(isActive: Bool, otherwise: Color = .clear, in shape: some Shape) -> some View {
        modifier(SpotFill(isActive: isActive, otherwise: otherwise, shape: shape))
    }
}
