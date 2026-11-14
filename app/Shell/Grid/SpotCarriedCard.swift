import OpenspotCore
import SwiftUI

struct SpotCarriedCard: View {
    let model: SpotsModel
    let panelOrigin: CGPoint

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
                    model: model,
                    onTap: {}
                )
                .modifier(SpotLiftedCard(isLifted: !carry.isLanding, isSolid: true, size: carry.size))
                .transition(.asymmetric(insertion: .scale(scale: 1 / MotionTokens.liftedScale), removal: .opacity))
            }
        }
        .modifier(CarriedPlace(lift: model.lift, panelOrigin: panelOrigin))
        .allowsHitTesting(false)
    }
}

private struct CarriedPlace: ViewModifier {
    let lift: SpotLift
    let panelOrigin: CGPoint

    func body(content: Content) -> some View {
        content.offset(x: panelOrigin.x + lift.origin.x, y: panelOrigin.y + lift.origin.y)
    }
}
