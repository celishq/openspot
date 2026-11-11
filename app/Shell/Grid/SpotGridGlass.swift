import OpenspotCore
import SwiftUI

/// The blur under every card of the grid: one blur view, seen through the shapes of the cards, and a stronger one seen
/// through the card that the person presses. A card moves, shrinks and fades its own shape, so no blur view moves with it,
/// and a press adds no view.
struct SpotGridGlass: View {
    /// The shape of one card in the mask.
    struct Card: Identifiable {
        let id: String
        let size: SpotSize
        /// Where the shape lies, and how it shrinks and fades on the push of an open sheet.
        let motion: SpotPushedCard
        /// Whether the card draws a solid fill or lies under the open sheet, so no blur shows through it.
        let isCovered: Bool
        /// Whether the person presses the card, which grows it and shows the stronger blur through it.
        let isPressed: Bool
        /// Whether the person drags the card in Edit Spots, which grows it and moves it with the pointer.
        let isLifted: Bool
        /// Whether the card is lifted or still lands, when it shows no press.
        let isHeld: Bool
    }

    let cards: [Card]
    /// The cards that a press can grow: each card while no sheet is built, and none while one is, so that a sheet's motion
    /// moves no shape of the stronger blur.
    let pressable: [Card]
    let size: CGSize
    let lift: SpotLift
    @Environment(\.spotIsShown) private var isShown

    /// How far the blur reaches past the grid on each side, so that a pushed card keeps its blur.
    private static let reach = SpotTokens.halo

    var body: some View {
        ZStack(alignment: .topLeading) {
            glass(radius: SpotTheme.blur, isPress: false)
            glass(radius: SpotTheme.blur * SpotMotion.pressedGlass, isPress: true)
                .opacity(pressable.contains(where: \.isPressed) ? 1 : 0)
        }
        .padding(-Self.reach)
        .opacity(isShown ? 1 : 0.001)
        .animation(SpotMotion.surface(isShown: isShown), value: isShown)
        .allowsHitTesting(false)
    }

    /// One blur seen through the shapes of the cards: each card that no fill covers, or with `isPress` only the pressed one.
    private func glass(radius: CGFloat, isPress: Bool) -> some View {
        let reach = Self.reach
        return SpotBlur(radius: isShown ? radius : 0)
            .overlay(SpotTheme.glass)
            .frame(width: size.width + 2 * reach, height: size.height + 2 * reach)
            .mask(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(isPress ? pressable : cards) { shape(of: $0, isPress: isPress) }
                }
                .offset(x: reach, y: reach)
                .frame(width: size.width + 2 * reach, height: size.height + 2 * reach, alignment: .topLeading)
            }
    }

    private func shape(of card: Card, isPress: Bool) -> some View {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: card.size), style: .continuous)
            .frame(width: SpotTokens.width(columns: card.size.columns), height: SpotTokens.height(rows: card.size.rows))
            .scaleEffect(isPress && card.isPressed ? SpotMotion.pressedScale : 1)
            .animation(SpotMotion.press, value: isPress && card.isPressed)
            .scaleEffect(isShown ? 1 : SpotMotion.hiddenScale)
            .scaleEffect(card.isLifted ? SpotMotion.liftedScale : 1)
            .modifier(SpotCardPlace(motion: card.motion, lift: card.isLifted ? lift : nil))
            .opacity(card.isCovered || (isPress && !card.isPressed) ? 0 : 1)
    }
}
