import OpenspotCore
import SwiftUI

/// One part of a moving sheet, placed, faded and sized on each frame from the sheet's progress: 0 on its card and 1 open.
/// The progress rides the sheet's own motion, so the part keeps no clock of its own, and only this modifier reruns.
struct SpotMorphLook: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    var offset: (Double) -> CGSize = { _ in .zero }
    var opacity: (Double) -> Double = { _ in 1 }
    var scale: (Double) -> Double = { _ in 1 }

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale(progress))
            .opacity(max(opacity(progress), SpotMotion.coveredCardOpacity))
            .offset(offset(progress))
    }
}

extension View {
    /// Places, fades and sizes this part from the progress of the sheet's motion.
    func morph(
        _ progress: Double,
        offset: @escaping (Double) -> CGSize = { _ in .zero },
        opacity: @escaping (Double) -> Double = { _ in 1 },
        scale: @escaping (Double) -> Double = { _ in 1 }
    ) -> some View {
        modifier(SpotMorphLook(progress: progress, offset: offset, opacity: opacity, scale: scale))
    }
}
