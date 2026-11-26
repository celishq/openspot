import OpenspotCore
import SwiftUI

struct StoreCarriedCard: View {
    let drag: StoreDrag
    let cards: [StoreCard]

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let carry = drag.carry, let card = cards.first(where: { $0.id == carry.id }) {
                StoreCardPreview(spot: card.spot, face: card.preview.face, size: card.preview.size, scale: 1)
                    .modifier(SpotLiftedCard(isLifted: true, isSolid: true, size: card.preview.size))
                    .offset(x: carry.frame.minX, y: carry.frame.minY)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
