import AppKit
import OpenspotCore
import SwiftUI

struct SpotPeekThumbnail: View {
    let path: String
    @Environment(\.displayScale) private var scale
    @State private var loaded: (path: String, image: NSImage)?

    var body: some View {
        Group {
            if let image = SpotPeekThumbnails.shared.cached(path) ?? (loaded?.path == path ? loaded?.image : nil) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                SpotItemIcon(icon: FileIcon(path: path), glyph: nil, symbol: nil, size: SpotTokens.listIconSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: path) {
            guard let image = await SpotPeekThumbnails.shared.image(path, scale: scale) else { return }
            loaded = (path, image)
        }
    }
}
