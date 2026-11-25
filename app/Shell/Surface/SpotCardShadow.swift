import OpenspotCore
import SwiftUI

struct SpotCardShadow<Edge: Shape>: View {
    let shape: Edge

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
