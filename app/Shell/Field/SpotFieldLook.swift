import OpenspotCore
import SwiftUI

struct SpotFieldLook: View {
    let query: String
    let title: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpotSurfaceShape(rect: SpotFieldView.sheetRow, radius: SpotFieldView.sheetRadius)
                .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            Image(systemName: "magnifyingglass")
                .modifier(SpotSecondaryText())
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.rowHeight)
                .offset(x: SpotFieldView.sheetGlyphLeft, y: SpotFieldView.sheetTop)
            words
                .font(SpotType.input)
                .lineLimit(1)
                .frame(width: SpotFieldView.fieldTextWidth, height: SpotTokens.rowHeight, alignment: .leading)
                .offset(x: SpotFieldView.sheetTextLeft, y: SpotFieldView.sheetTop)
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var words: some View {
        if query.isEmpty {
            Text("\(SearchPrompt.verb) \(SearchPrompt.word(for: title))")
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
        } else {
            Text(query)
                .foregroundStyle(SpotTheme.ink)
        }
    }
}
