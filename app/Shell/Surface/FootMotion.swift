import OpenspotCore
import SwiftUI

struct FootMotion<Content: View>: View, @preconcurrency Animatable {
    var foot: PanelFoot
    var motion: SheetMotion
    @ViewBuilder let content: (CGFloat) -> Content

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
        get { AnimatablePair(AnimatablePair(foot.closed, foot.open), motion.progress) }
        set {
            foot.closed = newValue.first.first
            foot.open = newValue.first.second
            motion.progress = newValue.second
        }
    }

    var body: some View {
        content(motion.place(of: foot))
    }
}
