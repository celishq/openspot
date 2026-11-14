import OpenspotCore
import SwiftUI

struct PanelSpan: ViewModifier {
    let panels: GridPanels

    func body(content: Content) -> some View {
        content
            .frame(width: panels.frame.width, height: panels.frame.height, alignment: .topLeading)
            .offset(x: panels.frame.minX)
    }
}
