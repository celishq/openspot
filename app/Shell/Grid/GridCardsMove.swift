import OpenspotCore
import SwiftUI

struct GridCardsMove: ViewModifier {
    let model: SpotsModel
    @Environment(\.spotMoves) private var moves

    func body(content: Content) -> some View {
        content.environment(\.spotMoves, moves && model.cardsMove)
    }
}
