import OpenspotCore
import SwiftUI

struct NodeCardPart: View {
    let node: ViewNode
    let label: AnyView?
    let look: SpotPart.Look?
    @Environment(\.spotNode) private var context

    var body: some View {
        let actions = context.actions
        let onSlot: (String, String?) -> Void = { actions.slot($0, $1) }
        if let label {
            Button { onSlot(node.id, nil) } label: { label }.buttonStyle(.plain)
        } else if let part = actions.part(of: node) {
            if part.number != nil {
                GeometryReader { room in
                    SpotSlotView(part: part, partLook: look, height: room.size.height, look: part.number?.look ?? .stat, onSlot: onSlot)
                }
                .frame(idealWidth: node.naturalSize.width, idealHeight: node.naturalSize.height)
            } else {
                SpotSlotView(part: part, partLook: look, onSlot: onSlot)
            }
        }
    }
}
