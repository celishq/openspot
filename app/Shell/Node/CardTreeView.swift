import OpenspotCore
import SwiftUI

struct CardTreeView: View {
    let face: CardFace
    let size: SpotSize
    var isPressed = false
    var model: SpotsModel?
    var index = -1
    var onSlot: (String, String?) -> Void = { _, _ in }

    var body: some View {
        let follows = !face.tree.places.isDisjoint(with: [.selected, .focus])
        let isSelected = follows && model?.selected == index
        let outset = SpotTokens.cardPadding(for: size, isDrawn: true)
        NodeTree(tree: face.tree, pictureTimes: [:], outset: outset)
            .environment(\.spotSurfaceEdge, SurfaceEdge(card: size))
            .clipShape(SpotRoundShape(SurfaceEdge(card: size).outset(by: outset)))
            .environment(\.spotNodeVariants, Style.Variant.card(size).union(isPressed ? [.pressed] : []).union(isSelected ? [.selected, .focus] : []))
            .environment(\.spotNodeParts, nodeParts)
    }

    private var nodeParts: NodeParts {
        let onSlot = onSlot
        return NodeParts(part: { node, label, look in
            if let label { return AnyView(Button { onSlot(node.id, nil) } label: { label }.buttonStyle(.plain)) }
            guard let part = node.part else { return AnyView(EmptyView()) }
            return AnyView(NodeCardPart(part: part, look: look, size: node.naturalSize, onSlot: onSlot))
        })
    }
}
