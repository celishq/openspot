import OpenspotCore
import SwiftUI

struct SpotMenuFocus: ViewModifier {
    let model: SpotsModel
    let index: Int?

    func body(content: Content) -> some View {
        let shade = model.gridShade
        let dims = index.map(shade.dims) ?? (shade.isOn && shade.coversField)
        content
            .opacity(dims ? SpotTheme.menuDim : 1)
            .offset(y: index.map(shade.offset) ?? 0)
    }
}
