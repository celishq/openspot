import OpenspotCore
import SwiftUI

struct NodeCardPart: View {
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    let onSlot: (String, String?) -> Void

    var body: some View {
        if part.number != nil {
            GeometryReader { room in
                SpotSlotView(part: part, partLook: look, height: room.size.height, look: part.number?.look ?? .stat, onSlot: onSlot)
            }
            .frame(idealWidth: size.width, idealHeight: size.height)
        } else {
            SpotSlotView(part: part, partLook: look, onSlot: onSlot)
        }
    }
}
