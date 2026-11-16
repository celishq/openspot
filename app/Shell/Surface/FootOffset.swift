import OpenspotCore
import SwiftUI

struct FootOffset: ViewModifier, @preconcurrency Animatable {
    var foot: PanelFoot
    var motion: SheetMotion
    let inset: CGFloat

    var animatableData: AnimatablePair<PanelFoot.AnimatableData, Double> {
        get { AnimatablePair(foot.animatableData, motion.progress) }
        set {
            foot.animatableData = newValue.first
            motion.progress = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content.offset(y: motion.place(of: foot) - inset)
    }
}

extension PanelFoot: @retroactive Animatable {
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(closed, open) }
        set {
            closed = newValue.first
            open = newValue.second
        }
    }
}
