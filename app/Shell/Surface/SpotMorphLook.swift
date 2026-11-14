import OpenspotCore
import SwiftUI

struct SpotMorphLook: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    var offset: (Double) -> CGSize = { _ in .zero }
    var opacity: (Double) -> Double = { _ in 1 }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(max(opacity(progress), MotionTokens.hiddenOpacity))
            .offset(offset(progress))
    }
}

extension View {
    func morph(
        _ progress: Double,
        offset: @escaping (Double) -> CGSize = { _ in .zero },
        opacity: @escaping (Double) -> Double = { _ in 1 }
    ) -> some View {
        modifier(SpotMorphLook(progress: progress, offset: offset, opacity: opacity))
    }
}
