import AppKit
import OpenspotCore
import QuickLookThumbnailing
import SwiftUI

struct SpotPreviewPicture: View {
    let picture: AttachmentPreview.Picture
    @Environment(\.displayScale) private var scale
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            SpotRoundShape(radius: SpotTokens.attachmentPictureRadius)
                .fill(SpotTheme.ink.opacity(SpotTheme.fill))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbol)
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
            }
        }
        .frame(width: SpotTokens.attachmentPicture, height: SpotTokens.attachmentPicture)
        .clipShape(SpotRoundShape(radius: SpotTokens.attachmentPictureRadius))
        .task(id: picture) { image = await Self.image(of: picture, scale: scale) }
    }

    private var symbol: String {
        if case .symbol(let name) = picture { name } else { AttachmentChip.loadingSymbol }
    }

    private static func image(of picture: AttachmentPreview.Picture, scale: CGFloat) async -> NSImage? {
        switch picture {
        case .symbol: return nil
        case .data(let data): return NSImage(data: data)
        case .file(let path):
            let side = SpotTokens.attachmentPicture
            let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path), size: CGSize(width: side, height: side), scale: scale, representationTypes: .thumbnail)
            return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
    }
}
