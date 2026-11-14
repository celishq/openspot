import SwiftUI

struct SpotFloatGlass<Edge: Shape>: View {
    let shape: Edge

    var body: some View {
        SpotBlur(radius: SpotTheme.blur)
            .overlay(SpotTheme.glass)
            .clipShape(shape)
    }
}
