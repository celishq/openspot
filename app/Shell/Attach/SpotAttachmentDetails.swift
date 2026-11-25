import OpenspotCore
import SwiftUI

struct SpotAttachmentDetails: View {
    let model: SpotsModel

    var body: some View {
        let isOpen = model.details != nil
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(SpotTheme.attachmentDivider)
                .frame(height: SpotTokens.dividerHeight)
            ZStack(alignment: .leading) {
                if let details = model.heldDetails {
                    words(of: details)
                        .id(details)
                        .transition(.opacity)
                }
            }
            .morph(isOpen ? 1 : 0, opacity: { SheetMorph.contentOpacity(at: $0, isOpen: isOpen) })
            .padding(.horizontal, SpotTokens.padding + SpotTokens.glyphInset)
            .padding(.top, SpotTokens.detailsTop)
            .padding(.bottom, SpotTokens.detailsFoot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: SpotFieldView.rect.width, height: SpotTokens.detailsHeight(lines: SpotTokens.detailsLineLimit), alignment: .top)
    }

    private func words(of details: AttachmentDetails) -> some View {
        NodeTree(tree: details.tree, pictureTimes: [:])
            .environment(\.spotNode, NodeContext(variants: AttachmentDetails.variants))
            .frame(width: SpotTokens.detailsWidth, height: SpotTokens.detailsContentHeight, alignment: .topLeading)
            .clipped()
            .accessibilityElement(children: .combine)
    }
}
