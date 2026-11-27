import OpenspotCore
import SwiftUI

struct SpotMorphLook: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    var offset: ((Double) -> CGSize)?
    var opacity: ((Double) -> Double)?

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(max(opacity?(progress) ?? 1, MotionTokens.hiddenOpacity))
            .offset(offset?(progress) ?? .zero)
    }
}

extension View {
    func morph(
        _ progress: Double,
        offset: ((Double) -> CGSize)? = nil,
        opacity: ((Double) -> Double)? = nil
    ) -> some View {
        modifier(SpotMorphLook(progress: offset == nil && opacity == nil ? 0 : progress, offset: offset, opacity: opacity))
    }
}
