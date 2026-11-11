import OpenspotCore
import SwiftUI

/// What the panel's window shows: the panel, and in Edit Spots the dock under it, which fades in, and the card that the
/// person carries over both, and the tip over all of them. The window's frame changes at once, so the places in it never animate; only the panel's glide in Edit Spots does.
struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .animation(nil) { $0.offset(x: place.panel.x, y: place.panel.y) }
                .offset(y: place.lift)
            if let dock = place.dock {
                SpotDockView(model: model, size: dock.size)
                    .environment(\.spotIsShown, model.isShown)
                    .animation(nil) { $0.offset(x: dock.minX, y: dock.minY) }
                    .opacity(place.isOut ? 1 : 0.001)
            }
            SpotCarriedCard(model: model, panel: place.panel)
                .environment(\.spotIsShown, model.isShown)
            SpotTipView(model: model, panel: place.panel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
