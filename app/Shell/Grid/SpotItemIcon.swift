import OpenspotCore
import SwiftUI

struct SpotItemIcon: View {
    let icon: FileIcon?
    let glyph: String?
    let symbol: String?
    let size: CGFloat
    let swatch: String?

    init(item: SpotItem, size: CGFloat) {
        self.init(icon: item.icon, glyph: item.glyph, symbol: item.symbol, size: size, swatch: item.swatch)
    }

    init(icon: FileIcon?, glyph: String?, symbol: String?, size: CGFloat, swatch: String? = nil) {
        self.icon = icon
        self.glyph = glyph
        self.symbol = symbol
        self.size = size
        self.swatch = swatch
    }

    static func prepare(_ items: ArraySlice<SpotItem>, size: CGFloat) {
        SpotGlyphPicture.prepare(items.compactMap(\.glyph), side: size, fontSize: size * SpotType.itemGlyphShare)
    }

    static func prepare(glyphs: [String], size: CGFloat) {
        SpotGlyphPicture.prepare(glyphs, side: size, fontSize: size * SpotType.itemGlyphShare)
    }

    static func bind(glyphs: [String]) {
        SpotGlyphShelf.bind(glyphs, side: SpotTokens.listIconSize, fontSize: SpotTokens.listIconSize * SpotType.itemGlyphShare)
    }

    var body: some View {
        if let swatch {
            let side = size * SpotTokens.swatchShare
            SpotRoundShape(radius: side * SpotTokens.swatchCornerShare)
                .fill(SpotColorBar.color(swatch))
                .frame(width: side, height: side)
                .frame(width: size, height: size)
        } else if let icon {
            SpotFileIconView(icon: icon, size: size)
        } else if let glyph, let picture = SpotGlyphPicture.image(glyph, side: size, fontSize: size * SpotType.itemGlyphShare) {
            Image(decorative: picture, scale: SpotGlyphPicture.scale)
                .frame(width: size, height: size)
        } else if let glyph {
            Text(glyph)
                .font(SpotType.itemGlyph(side: size))
                .frame(width: size, height: size)
        } else if let symbol {
            Image(systemName: symbol)
                .font(SpotType.itemSymbol(side: size))
                .foregroundStyle(SpotTheme.glassInk)
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
                Image(decorative: image, scale: SpotTokens.pictureScale)
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
