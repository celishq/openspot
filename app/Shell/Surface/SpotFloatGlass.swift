import SwiftUI

struct SpotFloatGlass<Edge: Shape>: View {
    let shape: Edge

    var body: some View {
        Color.clear.glassEffect(.regular, in: shape)
    }
}
