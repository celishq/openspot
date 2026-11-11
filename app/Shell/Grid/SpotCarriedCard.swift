import OpenspotCore
import SwiftUI

/// The card that the person carries in Edit Spots, over the panel and the dock: lifted on its solid fill, where the pointer
/// holds it. It grows as it lifts, settles to its size as it glides to its place, and fades when a release on the dock
/// turns its spot off. Only its place reads the lift, so a move of the pointer redraws that alone.
struct SpotCarriedCard: View {
    let model: SpotsModel
    /// Where the panel lies in the window.
    let panel: CGPoint

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let carry = model.carry {
                SpotCardView(
                    entry: carry.entry,
                    size: carry.size,
                    index: -1,
                    isPressed: false,
                    takesDrag: false,
                    isDropTarget: false,
                    chainLetter: nil,
                    showsChain: false,
                    model: model,
                    onTap: {}
                )
                .modifier(SpotLiftedCard(isLifted: !carry.isLanding, isSolid: true, size: carry.size))
                .transition(.asymmetric(insertion: .scale(scale: 1 / SpotMotion.liftedScale), removal: .opacity))
            }
        }
        .modifier(CarriedPlace(lift: model.lift, panel: panel))
        .allowsHitTesting(false)
    }
}

/// Moves the carried card to where the lift puts it.
private struct CarriedPlace: ViewModifier {
    let lift: SpotLift
    let panel: CGPoint

    func body(content: Content) -> some View {
        content.offset(x: panel.x + lift.origin.x, y: panel.y + lift.origin.y)
    }
}
