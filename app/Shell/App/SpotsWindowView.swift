import OpenspotCore
import SwiftUI

struct SpotsWindowView: View {
    let model: SpotsModel
    let place: SpotsWindowPlace

    var body: some View {
        let origin = CGPoint(x: place.left, y: place.top)
        ZStack(alignment: .topLeading) {
            if model.isArranging, let screen = place.screen {
                SpotArrangeView(model: model, size: screen, panelOrigin: origin)
                    .transition(.opacity)
            }
            SpotsView(model: model)
                .animation(nil) { $0.offset(x: origin.x, y: origin.y) }
            SpotPeekView(model: model)
                .environment(\.spotIsShown, model.isShown)
                .animation(nil) { $0.offset(x: origin.x, y: origin.y) }
            SpotCarriedCard(model: model, panelOrigin: origin)
                .environment(\.spotIsShown, model.isShown)
            SpotTipView(model: model, panelOrigin: origin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(SpotLoadedTheme.shared.layout)
    }
}
