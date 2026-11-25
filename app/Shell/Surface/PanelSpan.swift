import OpenspotCore
import SwiftUI

struct PanelSpan: ViewModifier {
    let columns: GridColumns

    func body(content: Content) -> some View {
        content
            .frame(width: columns.frame.width, height: columns.frame.height, alignment: .topLeading)
            .offset(x: columns.frame.minX)
    }
}
