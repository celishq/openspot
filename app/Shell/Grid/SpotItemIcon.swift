import OpenspotCore
import SwiftUI

struct SpotItemIcon: View {
    let icon: FileIcon?
    let glyph: String?
    let symbol: String?
    let size: CGFloat

    private static let glyphScale = 0.8

    init(item: SpotItem, size: CGFloat) {
        self.init(icon: item.icon, glyph: item.glyph, symbol: item.symbol, size: size)
    }

    init(icon: FileIcon?, glyph: String?, symbol: String?, size: CGFloat) {
        self.icon = icon
        self.glyph = glyph
        self.symbol = symbol
        self.size = size
    }

    static func prepare(_ items: ArraySlice<SpotItem>, size: CGFloat) {
        SpotGlyphPicture.prepare(items.compactMap(\.glyph), side: size, fontSize: size * glyphScale)
    }

    static func prepare(glyphs: [String], size: CGFloat) {
        SpotGlyphPicture.prepare(glyphs, side: size, fontSize: size * glyphScale)
    }

    static func bind(glyphs: [String]) {
        SpotGlyphShelf.bind(glyphs, side: SpotTokens.listIconSize, fontSize: SpotTokens.listIconSize * glyphScale)
    }

    var body: some View {
        if let icon {
            SpotFileIconView(icon: icon, size: size)
        } else if let glyph, let picture = SpotGlyphPicture.image(glyph, side: size, fontSize: size * Self.glyphScale) {
            Image(decorative: picture, scale: SpotGlyphPicture.scale)
                .frame(width: size, height: size)
        } else if let glyph {
            Text(glyph)
                .font(.system(size: size * Self.glyphScale))
                .frame(width: size, height: size)
        } else if let symbol {
            Image(systemName: symbol)
                .font(.system(size: size * 0.7, weight: .medium))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: size, height: size)
        }
    }
}

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
