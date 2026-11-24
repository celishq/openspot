import OpenspotCore
import SwiftUI

struct SpotPushedCard: ViewModifier, @preconcurrency Animatable {
    var offset: CGSize
    var share: Double
    let base: CGSize
    let push: SheetPush?
    let placement: SpotPlacement
    let anchor: UnitPoint

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double> {
        get { AnimatablePair(AnimatablePair(offset.width, offset.height), share) }
        set {
            offset = CGSize(width: newValue.first.first, height: newValue.first.second)
            share = newValue.second
        }
    }

    func body(content: Content) -> some View {
        let moved = CGSize(width: offset.width - base.width, height: offset.height - base.height)
        let faded = SheetPush.fade(of: placement, in: push, movedBy: moved, share: share)
        let pose = push?.pose(of: placement, movedBy: moved) ?? moved
        return content
            .scaleEffect(1 - (1 - MotionTokens.pushedScale) * faded, anchor: anchor)
            .opacity(1 - (1 - MotionTokens.hiddenOpacity) * faded)
            .offset(x: base.width + pose.width, y: base.height + pose.height)
            .allowsHitTesting(SheetPush.takesClicks(atFade: faded))
    }
}
