import OpenspotCore
import SwiftUI

struct NodeNumber: View {
    let node: ViewNode
    let look: SpotPart.Look?
    @Environment(\.spotNode) private var context

    var body: some View {
        if let part = context.actions.part(of: node) {
            NodePartFrame(node: node, part: part, look: look) { size in
                NumberDrawing(part: part, look: look, size: size, isCard: context.isCard)
            }
        }
    }
}

private struct NumberDrawing: View {
    let part: SpotPart
    let look: SpotPart.Look?
    let size: CGSize
    let isCard: Bool
    @Environment(\.spotSurfaceEdge) private var surface

    var body: some View {
        let figure = part.number?.look ?? .stat
        if isCard {
            GeometryReader { room in
                let font = fontSize(height: room.size.height)
                SpotNumberView(part: part, look: figure, font: SpotType.slotNumber(size: font), leastScale: font > SpotType.slotNumberSize ? SpotType.leastBigNumberScale : SpotType.leastNumberScale)
            }
            .frame(idealWidth: size.width, idealHeight: size.height)
        } else {
            let inset = look == .bare ? 0 : figure == .ring ? SpotTokens.partGap : SpotTokens.padding
            SpotNumberView(part: part, look: figure, font: SpotType.number, leastScale: SpotType.leastValueScale, alignment: look == .bare ? .trailing : .leading, inset: inset)
                .frame(width: size.width, height: size.height)
                .background(SpotTheme.ink.opacity(look == .bare ? 0 : SpotTheme.fill), in: SpotRoundShape(surface.inner()))
        }
    }

    private func fontSize(height: CGFloat) -> CGFloat {
        part.title == nil ? height * SpotType.slotNumberShare : SpotType.slotNumberSize
    }
}
