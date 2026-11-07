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
        /// The shares of the sheet's motion over which this card fades.
        let fade: ClosedRange<Double>
        /// How many cells lie between this card and the open card.
        let ring: Int
        /// Whether the card draws a solid fill or lies under the open sheet, so no blur shows through it.
        let isCovered: Bool
    }

    let cards: [Card]
    let isSheetOpen: Bool
    let size: CGSize
    @Environment(\.spotIsShown) private var isShown

    /// How far the blur reaches past the grid on each side, so that a pushed card keeps its blur.
    private static let reach = SpotTokens.halo

    var body: some View {
        let reach = Self.reach
        SpotBlur(radius: isShown ? SpotTheme.blur : 0)
            .overlay(SpotTheme.glass)
            .frame(width: size.width + 2 * reach, height: size.height + 2 * reach)
            .mask(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(cards) { shape(of: $0) }
                }
                .offset(x: reach, y: reach)
                .frame(width: size.width + 2 * reach, height: size.height + 2 * reach, alignment: .topLeading)
            }
            .padding(-reach)
            .opacity(isShown ? 1 : 0)
            .animation(SpotMotion.surface(isShown: isShown), value: isShown)
            .allowsHitTesting(false)
    }

    private func shape(of card: Card) -> some View {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: card.size), style: .continuous)
            .frame(width: SpotTokens.width(columns: card.size.columns), height: SpotTokens.height(rows: card.size.rows))
            .animation(SpotMotion.cardShrink(isSheetOpen: isSheetOpen, fade: card.fade, ring: card.ring)) { $0.scaleEffect(card.scale) }
            .animation(SpotMotion.cardFade(isSheetOpen: isSheetOpen, fade: card.fade, ring: card.ring)) {
                $0.opacity(isSheetOpen ? SpotMotion.coveredCardOpacity : 1)
            }
            .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale)
            .offset(card.offset)
            .opacity(card.isCovered ? 0 : 1)
    }
}
