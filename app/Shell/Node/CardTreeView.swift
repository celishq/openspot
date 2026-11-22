import OpenspotCore
import SwiftUI

struct CardTreeView: View {
    let tree: ViewTree
    let size: SpotSize
    let parts: [SpotPart]
    var isPressed = false
    var model: SpotsModel?
    var index = -1
    var onSlot: (String, String?) -> Void = { _, _ in }

    var body: some View {
        let follows = !tree.places.isDisjoint(with: [.selected, .focus])
        let isSelected = follows && model?.selected == index
        let outset = SpotTokens.cardPadding(for: size, isDrawn: true)
        SheetTreeView(tree: tree, pictureTimes: [:], outset: outset)
            .environment(\.spotSurfaceEdge, SurfaceEdge(card: size))
            .clipShape(SpotRoundShape(SurfaceEdge(card: size).outset(by: outset)))
            .environment(\.spotNodeVariants, Style.Variant.card(size).union(isPressed ? [.pressed] : []).union(isSelected ? [.selected, .focus] : []))
            .environment(\.spotNodeParts, nodeParts)
    }

    private var nodeParts: NodeParts {
        let parts = parts
        let onSlot = onSlot
        return NodeParts(part: { id, label, look in
            if let label { return AnyView(Button { onSlot(id, nil) } label: { label }.buttonStyle(.plain)) }
            guard let part = parts.first(where: { $0.id == id }) else { return AnyView(EmptyView()) }
            return AnyView(NodeCardPart(part: part.drawn(as: look), onSlot: onSlot))
        })
    }
}
