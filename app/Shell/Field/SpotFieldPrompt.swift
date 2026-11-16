import OpenspotCore
import SwiftUI

struct SpotFieldPrompt: View {
    let word: String
    var progress: Double = 1

    var body: some View {
        HStack(spacing: 0) {
            Text("\(SearchPrompt.verb) ")
            ZStack(alignment: .leading) {
                Text(SearchPrompt.grid)
                    .morph(progress, opacity: SheetMorph.cardLook(at:))
                Text(word)
                    .morph(progress, opacity: SheetMorph.sheetLook(at:))
            }
        }
        .font(SpotType.input)
        .foregroundStyle(SpotTheme.glassSecondary)
        .lineLimit(1)
    }

    static var glyph: some View {
        Image(systemName: "magnifyingglass")
            .font(SpotType.input)
            .modifier(SpotSecondaryText())
            .frame(width: SpotTokens.glyphSize, height: SpotTokens.rowHeight)
    }
}
