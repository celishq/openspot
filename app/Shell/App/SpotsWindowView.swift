import OpenspotCore
import SwiftUI

/// What the panel's window shows: the panel, and in Edit Spots the dock under it, which fades in, and the card that the
/// person carries over both.
struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .offset(x: place.panel.x, y: place.panel.y)
            if let dock = place.dock {
                SpotDockView(model: model, size: dock.size)
                    .environment(\.spotIsShown, model.isShown)
                    .offset(x: dock.minX, y: dock.minY)
                    .opacity(place.isOut ? 1 : 0.001)
            }
            SpotCarriedCard(model: model, panel: place.panel)
                .environment(\.spotIsShown, model.isShown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
