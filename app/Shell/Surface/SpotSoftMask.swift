import OpenspotCore
import SwiftUI

struct SpotSoftMask: View, @preconcurrency Animatable {
    struct Edge {
        let inset: CGFloat
        let softness: CGFloat
    }

    static let blur = Edge(inset: SpotTokens.halo - 5, softness: 20)
    static let tint = Edge(inset: SpotTokens.halo * 0.58, softness: SpotTokens.halo / 4.7)

    var height: CGFloat
    let edge: Edge

    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: SpotTokens.radius + SpotTokens.halo - edge.inset, style: .continuous)
            .fill(Color.black)
            .padding(edge.inset)
            .frame(height: max(height, 2 * edge.inset))
            .blur(radius: edge.softness)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}
