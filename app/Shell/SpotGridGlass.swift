import OpenspotCore
import SwiftUI

/// The blur under every card of the grid: one blur view, seen through the shapes of the cards. A card moves, shrinks and
/// fades its own shape, so no blur view moves with it.
struct SpotGridGlass: View {
    /// The shape of one card in the mask.
    struct Card: Identifiable {
        let id: String
        let size: SpotSize
        /// Where the shape lies, and how it shrinks and fades on the push of an open sheet.
        let motion: SpotPushedCard
        /// Whether the card draws a solid fill or lies under the open sheet, so no blur shows through it.
        let isCovered: Bool
    }

    let cards: [Card]
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
            .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale)
            .modifier(card.motion)
            .opacity(card.isCovered ? 0 : 1)
    }
}
