import OpenspotCore
import SwiftUI

struct SpotFadeLook: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    let fade: (Double) -> Double
    @Environment(\.spotFade) private var outer

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.environment(\.spotFade, outer * max(fade(progress), MotionTokens.hiddenOpacity))
    }
}

extension View {
    func fade(_ progress: Double, by fade: @escaping (Double) -> Double) -> some View {
        modifier(SpotFadeLook(progress: progress, fade: fade))
    }
}
