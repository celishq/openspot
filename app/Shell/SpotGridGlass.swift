import OpenspotCore
import SwiftUI

/// The blur under every card of the grid: one blur view, seen through the shapes of the cards. A card moves, shrinks and
/// fades its own shape, so no blur view moves with it.
struct SpotGridGlass: View {
    /// The shape of one card in the mask.
    struct Card: Identifiable {
        let id: String
        let size: SpotSize
        let offset: CGSize
        let scale: CGFloat
        let rowsAway: Int
        /// Whether the card draws a solid fill or lies under the open sheet, so no blur shows through it.
        let isCovered: Bool
    }

    let cards: [Card]
    let isSheetOpen: Bool
    let size: CGSize
    @Environment(\.spotIsShown) private var isShown

    var body: some View {
        SpotBlur(radius: isShown ? SpotTheme.blur : 0)
            .overlay(SpotTheme.glass)
            .frame(width: size.width, height: size.height)
            .mask(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(cards) { shape(of: $0) }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .opacity(isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .allowsHitTesting(false)
    }

    private func shape(of card: Card) -> some View {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: card.size), style: .continuous)
            .frame(width: SpotTokens.width(columns: card.size.columns), height: SpotTokens.height(rows: card.size.rows))
            .scaleEffect(card.scale * (isShown ? 1 : SpotMotion.hiddenScale))
            .offset(card.offset)
            .animation(SpotMotion.cardFade(isSheetOpen: isSheetOpen, rowsAway: card.rowsAway)) { $0.opacity(isSheetOpen ? 0 : 1) }
            .opacity(card.isCovered ? 0 : 1)
    }
}
