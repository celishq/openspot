import OpenspotCore
import SwiftUI

struct StoreSheetPreview: View {
    let model: SpotsModel
    let spot: Spot
    let output: Frame
    var selects = true
    var fit: CGFloat = .infinity

    var body: some View {
        StorePreviewUnit(label: "Sheet") {
            SpotSampleSheet(model: model, entry: SpotsModel.Entry(spot: spot, run: nil), selects: selects, fit: fit) { output }
        }
    }
}
