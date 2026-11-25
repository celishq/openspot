import OpenspotCore
import SwiftUI

struct SpotShelfCard: View, Equatable {
    let entry: SpotsModel.Entry
    let name: ShelfName

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            SpotGlyph(entry: entry)
            ViewThatFits(in: .horizontal) {
                Text(name.text).lineLimit(1).fixedSize()
                ForEach(name.breaks, id: \.first) { line in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.first).lineLimit(1).fixedSize()
                        Text(line.rest).lineLimit(1).truncationMode(.tail).frame(minWidth: 0, idealWidth: 0, alignment: .leading)
                    }
                }
                Text(name.text).lineLimit(1).truncationMode(.tail).frame(minWidth: 0, idealWidth: 0, alignment: .leading)
            }
            .font(SpotType.strong)
            .foregroundStyle(SpotTheme.ink)
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
