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
                    ZStack(alignment: .leading) {
                        words(of: preview)
                            .id(preview)
                            .transition(.opacity)
                    }
                    .transition(.opacity.combined(with: .offset(y: -SpotTokens.contextValueRise)))
                }
            }
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .padding(.top, SpotTokens.contextValuePadding)
            .padding(.bottom, SpotTokens.contextValueFoot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: SpotFieldView.rect.width, height: max(model.fieldValueRoom, SpotTokens.contextValueRoom(lines: 0)), alignment: .top)
    }

    private func words(of preview: ContextPreview) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.contextValueLineGap) {
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
                    .lineLimit(max(model.fieldValueLines, 1))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
