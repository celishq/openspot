import OpenspotCore
import SwiftUI

struct WorkCardView: View {
    let model: SpotsModel
    let stage: WorkCardStage

    private static let wordLines = 2

    var body: some View {
        if let card = stage.card {
            VStack(spacing: SpotTokens.padding) {
                Group {
                    if let entry = model.entry(card.spot) {
                        SpotGlyph(entry: entry, side: SpotTokens.workCardGlyph, font: SpotType.workGlyph)
                    }
                }
                .frame(height: SpotTokens.workCardGlyph)
                Text(card.words)
                    .font(SpotType.strong)
                    .foregroundStyle(SpotTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(Self.wordLines)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(Self.wordLines) * SpotType.titleLine, alignment: .top)
                WorkCardBar(fill: card.fill, width: SpotTokens.workCardSide - 2 * SpotTokens.workCardInset)
            }
            .padding(SpotTokens.workCardInset)
            .frame(width: SpotTokens.workCardSide, height: SpotTokens.workCardSide)
            .modifier(SpotGlass(shape: SpotRoundShape(radius: SpotTokens.cardRadius)))
            .accessibilityElement(children: .combine)
            .environment(\.spotIsShown, stage.isShown)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
