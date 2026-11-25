import OpenspotCore
import SwiftUI

struct SpotAttachmentPreview: View {
    let model: SpotsModel

    var body: some View {
        let isOpen = model.preview != nil
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SpotTheme.attachmentDivider)
                .frame(height: SpotTokens.dividerHeight)
            ZStack(alignment: .leading) {
                if let preview = model.previewLook {
                    words(of: preview)
                        .id(preview)
                        .transition(.opacity)
                }
            }
            .morph(isOpen ? 1 : 0, opacity: { SheetMorph.contentOpacity(at: $0, isOpen: isOpen) })
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .padding(.top, SpotTokens.attachmentValuePadding)
            .padding(.bottom, SpotTokens.attachmentValueFoot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: SpotFieldView.rect.width, height: SpotTokens.attachmentValueRoom(lines: SpotTokens.previewLines), alignment: .top)
    }

    private func words(of preview: AttachmentPreview) -> some View {
        NodeTree(tree: preview.face.tree, pictureTimes: [:])
            .environment(\.spotNode, NodeContext(variants: Style.Variant.card(.strip)))
            .frame(width: SpotTokens.attachmentValueWidth, height: SpotTokens.attachmentFaceHeight, alignment: .topLeading)
            .clipped()
            .accessibilityElement(children: .combine)
    }
}
