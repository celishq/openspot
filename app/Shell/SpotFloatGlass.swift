import SwiftUI

/// The sheet's own glass in a shape, under a control that floats over other parts, so that the control looks as it would
/// on the sheet and nothing sharp shows through it.
struct SpotFloatGlass<Edge: Shape>: View {
    let shape: Edge

    var body: some View {
        SpotBlur(radius: SpotTheme.blur)
            .overlay(SpotTheme.glass)
            .clipShape(shape)
    }
}
