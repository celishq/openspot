import OpenspotCore
import SwiftUI

struct NodeCardPart: View {
    let part: SpotPart
    let size: CGSize
    let onSlot: (String, String?) -> Void

    var body: some View {
        if part.number != nil {
            GeometryReader { room in
                SpotSlotView(part: part, height: room.size.height, look: part.numberLook(inSheet: room.size) ?? .stat, onSlot: onSlot)
            }
            .frame(idealWidth: size.width, idealHeight: size.height)
        } else {
            SpotSlotView(part: part, onSlot: onSlot)
        }
    }
}
