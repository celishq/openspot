import OpenspotCore
import SwiftUI

struct NodeCardPart: View {
    let part: SpotPart
    let onSlot: (String, String?) -> Void

    var body: some View {
        if part.number != nil {
            GeometryReader { room in
                SpotSlotView(part: part, height: room.size.height, look: part.numberLook(columns: room.size.width / SpotTokens.cell, rows: room.size.height / SpotTokens.cell) ?? .stat, onSlot: onSlot)
            }
            .frame(idealWidth: SpotTokens.cell, idealHeight: SpotTokens.listRow)
        } else {
            SpotSlotView(part: part, onSlot: onSlot)
        }
    }
}
