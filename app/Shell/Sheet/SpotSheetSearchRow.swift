import OpenspotCore
import SwiftUI

struct SpotSheetSearchRow: View {
    @Environment(\.spotSurfaceEdge) private var surface
    let title: String
    var query = ""

    var body: some View {
        HStack(spacing: SpotTokens.fieldTextGap) {
            Image(systemName: "magnifyingglass")
                .modifier(SpotSecondaryText())
                .frame(width: SpotTokens.listIconSize)
            Text(query.isEmpty ? "\(SearchPrompt.verb) \(SearchPrompt.word(for: title))" : query)
                .foregroundStyle(query.isEmpty ? SpotTheme.glassSecondary : SpotTheme.glassInk)
                .lineLimit(1)
        }
        .font(SpotType.input)
        .padding(.horizontal, SpotTokens.padding)
        .frame(maxWidth: .infinity, minHeight: SpotTokens.listRow, maxHeight: SpotTokens.listRow, alignment: .leading)
        .background(SpotTheme.highlight.opacity(SpotTheme.fill), in: SpotRoundShape(surface.inner()))
    }
}
