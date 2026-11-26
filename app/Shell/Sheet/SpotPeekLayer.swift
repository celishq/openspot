import OpenspotCore
import SwiftUI

struct SpotPeekLayer: View {
    let model: SpotsModel
    let item: SpotMenuAnchor.Item?

    var body: some View {
        if model.peekRect != nil {
            GeometryReader { proxy in
                SpotPeekView(model: model, row: item.map { proxy[$0.bounds] })
            }
        }
    }
}
