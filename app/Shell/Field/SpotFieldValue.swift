import OpenspotCore
import SwiftUI

struct SpotFieldValue: View {
    let model: SpotsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SpotTheme.contextDivider)
                .frame(height: SpotTokens.dividerHeight)
            ZStack(alignment: .leading) {
                if let preview = model.contextPreview {
                    words(of: preview)
                        .id(preview)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: SpotFieldView.rect.width, height: SpotTokens.contextValueRoom)
    }

    private func words(of preview: ContextPreview) -> some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            HStack(spacing: SpotTokens.previewCaptionGap) {
                Image(systemName: preview.symbol)
                Text(preview.caption)
                    .lineLimit(1)
            }
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            if !preview.text.isEmpty {
                Text(preview.text)
                    .font(SpotType.body)
                    .modifier(SpotInk())
                    .lineLimit(SpotTokens.previewLines)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
