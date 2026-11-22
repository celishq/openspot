import OpenspotCore
import SwiftUI

struct CardTreeView: View {
    let face: CardFace
    let size: SpotSize
    var isPressed = false
    var model: SpotsModel?
    var index = -1
    var spot: String?

    var body: some View {
        let follows = !face.tree.places.isDisjoint(with: [.selected, .focus])
        let isSelected = follows && model?.selected == index
        let outset = SpotTokens.cardPadding(for: size, isDrawn: true)
        NodeTree(tree: face.tree, pictureTimes: [:], outset: outset)
            .environment(\.spotSurfaceEdge, SurfaceEdge(card: size))
            .clipShape(SpotRoundShape(SurfaceEdge(card: size).outset(by: outset)))
            .environment(\.spotNode, context(isSelected: isSelected))
    }

    private func context(isSelected: Bool) -> NodeContext {
        var context = NodeContext(variants: Style.Variant.card(size).union(isPressed ? [.pressed] : []).union(isSelected ? [.selected, .focus] : []))
        if let model, let spot { context.actions = CardActions(model: model, spot: spot) }
        return context
    }
}
