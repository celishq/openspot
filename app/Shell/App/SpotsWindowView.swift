import OpenspotCore
import SwiftUI

struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        let origin = CGPoint(x: place.left, y: 0)
        ZStack(alignment: .topLeading) {
            SpotsView(model: model)
                .animation(nil) { $0.offset(x: origin.x, y: origin.y) }
            SpotCarriedCard(model: model, panelOrigin: origin)
                .environment(\.spotIsShown, model.isShown)
            SpotTipView(model: model, panelOrigin: origin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
