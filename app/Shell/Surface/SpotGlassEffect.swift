import SwiftUI

struct SpotGlassEffect<Edge: Shape>: ViewModifier {
    let isOn: Bool
    let shape: Edge
    @Environment(\.spotDrawsGlass) private var drawsGlass

    func body(content: Content) -> some View {
        if drawsGlass {
            content.glassEffect(isOn ? .regular : .identity, in: shape)
        } else {
            content.overlay { shape.stroke(SpotTheme.pictureRim.opacity(isOn ? 1 : 0), lineWidth: 0.5) }
        }
    }
}

extension View {
    func spotGlass(_ isOn: Bool = true, in shape: some Shape) -> some View {
        modifier(SpotGlassEffect(isOn: isOn, shape: shape))
    }
}
