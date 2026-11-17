import OpenspotCore
import SwiftUI

struct GridCardsMove: ViewModifier {
    let model: SpotsModel

    func body(content: Content) -> some View {
        content.environment(\.spotMoves, model.cardsMove)
    }
}
