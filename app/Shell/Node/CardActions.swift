import OpenspotCore
import SwiftUI

struct CardActions: NodeActions, @MainActor Equatable {
    let model: SpotsModel
    let spot: String

    static func == (one: CardActions, other: CardActions) -> Bool {
        one.model === other.model && one.spot == other.spot
    }

    func part(of node: ViewNode) -> SpotPart? {
        model.sheets[spot]?[cardPart: node.id] ?? node.part
    }

    func slot(_ id: String, _ value: String?) {
        model.setCardPart(spot, id, to: value)
    }

    func isSelected(_ node: ViewNode, in tree: ViewTree) -> Bool {
        false
    }
}
