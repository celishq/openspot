import OpenspotCore
import SwiftUI

struct SettingsCard: View {
    let model: SpotsModel
    let entry: SpotsModel.Entry

    var body: some View {
        SpotCardView(entry: entry, size: entry.size, index: Int.min, isPressed: false, takesDrag: false, isDropTarget: false, model: model)
            .frame(width: SpotTokens.width(columns: entry.size.columns), height: SpotTokens.height(rows: entry.size.rows))
            .allowsHitTesting(false)
    }
}
