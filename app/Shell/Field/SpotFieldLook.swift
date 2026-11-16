import OpenspotCore
import SwiftUI

struct SpotFieldLook: View {
    let query: String
    let title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotSurfaceShape(rect: SpotFieldView.sheetRow, radius: SpotFieldView.sheetRadius)
                .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            SpotFieldPrompt.glyph
                .offset(x: SpotFieldView.sheetGlyphLeft, y: SpotFieldView.sheetTop)
            words
                .frame(height: SpotTokens.rowHeight)
                .offset(x: SpotFieldView.sheetTextLeft, y: SpotFieldView.sheetTop)
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var words: some View {
        if query.isEmpty {
            SpotFieldPrompt(word: SearchPrompt.word(for: title))
        } else {
            Text(query)
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.glassInk)
                .lineLimit(1)
                .frame(width: SpotFieldView.fieldTextWidth, alignment: .leading)
        }
    }
}
