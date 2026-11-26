import OpenspotCore
import SwiftUI

struct SpotGlassEffect<Edge: Shape>: ViewModifier {
    let isOn: Bool
    let shape: Edge
    var glass: Glass?
    @Environment(\.spotDrawsGlass) private var drawsGlass

    func body(content: Content) -> some View {
        if drawsGlass {
            content.glassEffect(isOn ? glass ?? SpotTheme.glassVariant.tint(SpotTheme.glassTint) : .identity, in: shape)
        } else {
            content.overlay { shape.stroke(isOn ? SpotTheme.pictureRim : .clear, lineWidth: SpotTokens.pictureRimLine) }
        }
    }
}

extension View {
    func spotGlass(_ isOn: Bool = true, in shape: some Shape) -> some View {
        modifier(SpotGlassEffect(isOn: isOn, shape: shape))
    }

    func spotGlass(_ glass: Glass, in shape: some Shape) -> some View {
        modifier(SpotGlassEffect(isOn: true, shape: shape, glass: glass))
    }
}
