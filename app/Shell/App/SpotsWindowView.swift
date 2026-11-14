import OpenspotCore
import SwiftUI

/// What the panel's window shows: the panel, the card that the person carries over it, and the tip over both. The window's
/// frame changes at once, so the places in it never animate.
struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        let origin = CGPoint(x: place.left, y: 0)
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .animation(nil) { $0.offset(x: origin.x, y: origin.y) }
            SpotCarriedCard(model: model, panel: origin)
                .environment(\.spotIsShown, model.isShown)
            SpotTipView(model: model, panel: origin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
