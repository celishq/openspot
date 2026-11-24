import OpenspotCore
import SwiftUI

struct SpotAttachmentPreview: View {
    let model: SpotsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SpotTheme.attachmentDivider)
                .frame(height: SpotTokens.dividerHeight)
            ZStack(alignment: .leading) {
                if let preview = model.preview {
                    ZStack(alignment: .leading) {
                        words(of: preview)
                            .id(preview)
                            .transition(.opacity)
                    }
                    .transition(.opacity.combined(with: .offset(y: -SpotTokens.attachmentValueRise)))
                }
            }
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .padding(.top, SpotTokens.attachmentValuePadding)
            .padding(.bottom, SpotTokens.attachmentValueFoot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: SpotFieldView.rect.width, height: max(model.fieldRoom, SpotTokens.attachmentValueRoom(lines: 0)), alignment: .top)
    }

    private func words(of preview: AttachmentPreview) -> some View {
        VStack(alignment: .leading, spacing: SpotTokens.attachmentValueLineGap) {
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
                    .lineLimit(max(preview.lines, 1))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
