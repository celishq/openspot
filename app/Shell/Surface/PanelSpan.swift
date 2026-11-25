import OpenspotCore
import SwiftUI

struct PanelSpan: ViewModifier {
    let grid: OpenspotCore.GridLayout

    func body(content: Content) -> some View {
        content
            .frame(width: grid.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
    }
}
