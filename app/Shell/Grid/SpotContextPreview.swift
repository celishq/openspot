import OpenspotCore
import SwiftUI

struct SpotContextPreview: View, Equatable {
    let entry: SpotsModel.Entry
    let size: SpotSize

    var body: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            Capsule()
                .fill(SpotTheme.ink.opacity(SpotTheme.previewRule))
                .frame(width: SpotTokens.previewRule)
                .padding(.vertical, SpotTokens.previewRuleInset)
            if let file = entry.item?.icon {
                SpotItemIcon(icon: file, glyph: nil, symbol: nil, size: SpotTokens.previewIcon)
            }
            VStack(alignment: .leading, spacing: SpotType.lineGap) {
                caption
                Text(entry.state.title)
                    .font(SpotType.body)
                    .modifier(SpotInk())
                    .lineLimit(SpotTokens.previewLines)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, SpotTokens.padding)
        .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows), alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var caption: some View {
        HStack(spacing: SpotTokens.previewCaptionGap) {
            if let symbol = entry.item?.symbol {
                Image(systemName: symbol)
            }
            Text(entry.state.subtitle ?? "")
                .lineLimit(1)
        }
        .font(SpotType.detail)
        .modifier(SpotSecondaryText())
    }
}
