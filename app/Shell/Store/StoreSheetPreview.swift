import OpenspotCore
import SwiftUI

struct StoreSheetPreview: View {
    let model: SpotsModel
    let spot: Spot
    let output: Frame
    var selects = true

    var body: some View {
        StorePreviewUnit(label: "Sheet") {
            SpotSampleSheet(model: model, entry: SpotsModel.Entry(spot: spot, run: nil), selects: selects) { output }
                .background(SpotTheme.ink.opacity(SpotTheme.hover), in: SpotRoundShape(radius: SpotTokens.storeTileRadius))
        }
    }
}
