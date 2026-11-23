import OpenspotCore
import SwiftUI

struct WorkCardView: View {
    let model: SpotsModel
    let stage: WorkCardStage

    static let side: CGFloat = 200
    private static let inset: CGFloat = 20
    private static let glyphSide: CGFloat = 72
    private static let wordLines = 2

    var body: some View {
        if let card = stage.card {
            VStack(spacing: SpotTokens.padding) {
                Group {
                    if let entry = model.entry(card.spot) {
                        SpotGlyph(entry: entry, side: Self.glyphSide, font: SpotType.workGlyph)
                    }
                }
                .frame(height: Self.glyphSide)
                Text(card.words)
                    .font(SpotType.strong)
                    .foregroundStyle(SpotTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(Self.wordLines)
                    .frame(maxWidth: .infinity, minHeight: CGFloat(Self.wordLines) * SpotType.titleLine, alignment: .top)
                WorkCardBar(fill: card.fill, width: Self.side - 2 * Self.inset)
            }
            .padding(Self.inset)
            .frame(width: Self.side, height: Self.side)
            .modifier(SpotGlass(shape: SpotRoundShape(radius: SpotTokens.radius)))
            .accessibilityElement(children: .combine)
            .environment(\.spotIsShown, stage.isShown)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
