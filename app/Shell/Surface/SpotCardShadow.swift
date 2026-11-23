import OpenspotCore
import SwiftUI

struct SpotCardShadow: View {
    let shape: SpotRoundShape

    var body: some View {
        let size = CGFloat(SpotTokens.backdrop.shadow)
        shape
            .fill(SpotTheme.cardShadow)
            .blur(radius: size)
            .mask {
                Rectangle()
                    .padding(-SpotTokens.cardShadowReach * size)
                    .overlay { shape.blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}
