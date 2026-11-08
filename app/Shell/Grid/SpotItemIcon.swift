import OpenspotCore
import SwiftUI

/// The picture of an item: its image or the icon of its file, or else its glyph, or else its symbol, or else nothing.
struct SpotItemIcon: View {
    let item: SpotItem
    let size: CGFloat

    private static let glyphScale = 0.8

    var body: some View {
        if let icon = item.icon {
            SpotFileIconView(icon: icon, size: size)
        } else if let glyph = item.glyph, let picture = SpotGlyphPicture.image(glyph, side: size, fontSize: size * Self.glyphScale) {
            Image(decorative: picture, scale: SpotGlyphPicture.scale)
                .frame(width: size, height: size)
        } else if let glyph = item.glyph {
            Text(glyph)
                .font(.system(size: size * Self.glyphScale))
                .frame(width: size, height: size)
        } else if let symbol = item.symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: size, height: size)
        }
    }
}

/// A file's icon read from the store. Its place stays empty until the bitmap is ready.
private struct SpotFileIconView: View {
    let icon: FileIcon
    let size: CGFloat
    @State private var loaded: CGImage?

    var body: some View {
        Group {
            if let image = SpotIconStore.shared.cached(icon) ?? loaded {
                Image(decorative: image, scale: SpotIconStore.scale)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
        .task(id: icon) {
            loaded = await SpotIconStore.shared.image(icon)
        }
    }
}
