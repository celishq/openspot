import OpenspotCore
import SwiftUI

struct SpotGridGlass: View {
    struct Card: Identifiable {
        let id: String
        let size: SpotSize
        let motion: SpotPushedCard
        let isCovered: Bool
        let isPressed: Bool
        let isLifted: Bool
        let isHeld: Bool
        var focus = CardFocus.none
    }

    let cards: [Card]
    let pressable: [Card]
    let size: CGSize
    let lift: SpotLift
    @Environment(\.spotIsShown) private var isShown

    private static let blurReach = SpotTokens.halo

    var body: some View {
        ZStack(alignment: .topLeading) {
            glass(radius: SpotTheme.blur, isPress: false)
            glass(radius: SpotTheme.blur * MotionTokens.pressedGlass, isPress: true)
                .opacity(pressable.contains(where: \.isPressed) ? 1 : 0)
        }
        .padding(-Self.blurReach)
        .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        .allowsHitTesting(false)
    }

    private func glass(radius: CGFloat, isPress: Bool) -> some View {
        let reach = Self.blurReach
        return SpotBlur(radius: radius)
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
            .scaleEffect(isPress && card.isPressed ? MotionTokens.pressedScale : 1)
            .animation(SpotMotion.press, value: isPress && card.isPressed)
            .scaleEffect(isShown ? 1 : MotionTokens.hiddenScale)
            .scaleEffect(card.isLifted ? MotionTokens.liftedScale : 1)
            .modifier(SpotFocusLook(focus: card.focus))
            .modifier(SpotCardPlace(motion: card.motion, lift: card.isLifted ? lift : nil))
            .opacity(card.isCovered || (isPress && !card.isPressed) ? MotionTokens.hiddenOpacity : 1)
    }
}
