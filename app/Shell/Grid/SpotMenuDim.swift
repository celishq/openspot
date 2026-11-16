import OpenspotCore
import SwiftUI

struct SpotMenuDim: ViewModifier {
    let model: SpotsModel
    let index: Int?

    func body(content: Content) -> some View {
        let shade = model.gridShade
        let dims = index.map(shade.dims) ?? (shade.isOn && shade.coversField)
        content.opacity(dims ? SpotTheme.menuDim : 1)
    }
}
