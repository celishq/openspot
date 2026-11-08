import OpenspotCore
import SwiftUI

/// The place, shrink and fade of a card of the grid. The shrink and fade follow where the card is on its push, so that a
/// sheet that changes its size during its motion keeps them in step. A card that the push leaves in place fades with `share`.
struct SpotPushedCard: ViewModifier, @preconcurrency Animatable {
    var offset: CGSize
    /// How far the sheet is open, from 0 to 1.
    var share: Double
    /// Where the card lies with no push.
    let base: CGSize
    let push: SheetPush?
    let placement: SpotPlacement
    /// The point the card shrinks towards: its side that faces the sheet.
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
        let faded = push.flatMap { $0.fade(of: placement, movedBy: moved) } ?? share
        return content
            .scaleEffect(1 - (1 - SpotMotion.pushedScale) * faded, anchor: anchor)
            .opacity(1 - (1 - SpotMotion.coveredCardOpacity) * faded)
            .offset(offset)
    }
}
