import AppKit
import CoreText

/// Colour emoji drawn once into bitmaps in the display's colour space, so that a cell that shows one again only shows an image.
@MainActor
enum SpotGlyphPicture {
    static let scale: CGFloat = 2

    private final class Bitmap {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    private static let bitmaps: NSCache<NSString, Bitmap> = {
        let cache = NSCache<NSString, Bitmap>()
        cache.countLimit = 3000
        return cache
    }()

    /// The bitmap of a colour emoji in a square of this side, or nil for a glyph drawn as text in the ink colour.
    static func image(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard glyph.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0 == "\u{FE0F}" }) else { return nil }
        let key = "\(glyph)|\(side)|\(fontSize)" as NSString
        if let bitmap = bitmaps.object(forKey: key) { return bitmap.image }
        guard let image = draw(glyph, side: side, fontSize: fontSize) else { return nil }
        bitmaps.setObject(Bitmap(image), forKey: key)
        return image
    }

    private static func draw(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        let pixels = Int((side * scale).rounded(.up))
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [.font: NSFont.systemFont(ofSize: fontSize)]))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(x: (side - width) / 2, y: (side - ascent - descent) / 2 + descent)
        CTLineDraw(line, context)
        return context.makeImage()
    }
}
