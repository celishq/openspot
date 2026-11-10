import OpenspotCore
import SwiftUI

/// What the panel's window shows: the panel, and in Edit Spots the dock under it.
struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .offset(x: place.panel.x, y: place.panel.y)
            if let dock = place.dock {
                SpotDockView(model: model, size: dock.size)
                    .offset(x: dock.minX, y: dock.minY)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
