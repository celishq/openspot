import OpenspotCore
import SwiftUI

/// Lays a view of the center panel's size out across the panel with these side panels, from the left side panel's edge.
struct PanelSpan: ViewModifier {
    let panels: GridPanels

    func body(content: Content) -> some View {
        content
            .frame(width: panels.frame.width, height: panels.frame.height, alignment: .topLeading)
            .offset(x: panels.frame.minX)
    }
}
