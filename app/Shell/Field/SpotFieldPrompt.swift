import OpenspotCore
import SwiftUI

struct SpotFieldPrompt: View {
    let word: String
    var progress: Double = 1
    var grid = SearchPrompt.grid

    var body: some View {
        HStack(spacing: 0) {
            Text("\(SearchPrompt.verb) ")
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Text(SearchPrompt.grid)
                        .opacity(grid == SearchPrompt.grid ? 1 : MotionTokens.hiddenOpacity)
                    Text(SearchPrompt.actions)
                        .opacity(grid == SearchPrompt.actions ? 1 : MotionTokens.hiddenOpacity)
                }
                .morph(progress, opacity: SheetMorph.cardOpacity(at:))
                Text(word)
                    .morph(progress, opacity: SheetMorph.sheetOpacity(at:))
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
            .frame(width: SpotTokens.glyph, height: SpotTokens.cell)
    }
}
