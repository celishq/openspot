import OpenspotCore
import SwiftUI

struct StoreTileLift: View {
    let card: StoreCard

    var body: some View {
        StoreCardPreview(spot: card.spot, face: card.preview.face, size: card.preview.size, scale: 1)
            .modifier(SpotLiftedCard(isLifted: true, isSolid: true, size: card.preview.size))
            .environment(\.spotDrawsGlass, false)
    }
}
