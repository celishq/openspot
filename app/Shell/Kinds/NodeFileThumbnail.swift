import AppKit
import OpenspotCore
import QuickLookThumbnailing
import SwiftUI

struct NodeFileThumbnail: View {
    let path: String
    @Environment(\.displayScale) private var scale
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { room in
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    SpotItemIcon(icon: FileIcon(path: path), glyph: nil, symbol: nil, size: SpotTokens.pictureSide(in: room.size))
                }
            }
            .frame(width: room.size.width, height: room.size.height)
            .task(id: path) { image = await Self.image(of: path, side: max(room.size.width, room.size.height), scale: scale) }
        }
    }

    private static func image(of path: String, side: CGFloat, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: path), size: CGSize(width: side, height: side), scale: scale, representationTypes: .thumbnail)
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
