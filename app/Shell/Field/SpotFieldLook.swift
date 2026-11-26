import OpenspotCore
import SwiftUI

struct SpotFieldLook: View {
    let query: String
    let title: String
    let top: SheetTop

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotSurfaceShape(rect: SpotFieldView.sheetRow(top: top), radius: SpotFieldView.sheetRadius)
                .fill(SpotTheme.highlight.opacity(SpotTheme.fill))
            SpotFieldPrompt.glyph
                .offset(x: SpotFieldView.sheetGlyphLeft, y: SpotFieldView.sheetTop(top: top))
            words
                .frame(height: SpotTokens.cell)
                .offset(x: SpotFieldView.sheetTextLeft, y: SpotFieldView.sheetTop(top: top))
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var words: some View {
        if query.isEmpty {
            SpotFieldPrompt(word: SearchPrompt.word(for: title))
                .frame(width: SpotFieldView.fieldTextWidth, alignment: .leading)
        } else {
            Text(query)
                .font(SpotType.input)
                .foregroundStyle(SpotTheme.glassInk)
                .lineLimit(1)
                .frame(width: SpotFieldView.fieldTextWidth, alignment: .leading)
        }
    }
}
