import OpenspotCore
import SwiftUI

struct SpotShelfCard: View, Equatable {
    let entry: SpotsModel.Entry

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            SpotGlyph(entry: entry)
            Text(entry.spot.name)
                .font(SpotType.strong)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SpotTokens.shelfCardPadding)
        .frame(width: SpotTokens.shelfCard.width, height: SpotTokens.shelfCard.height)
        .background(SpotTheme.window, in: SpotRoundShape(radius: SpotTokens.shelfCardRadius))
        .shadow(color: SpotTheme.liftShadowColor.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.shelfShadow, y: SpotTheme.shelfShadowDrop)
        .contentShape(SpotRoundShape(radius: SpotTokens.shelfCardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
