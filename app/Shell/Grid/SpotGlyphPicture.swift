import AppKit
import CoreText

/// Colour emoji drawn once into bitmaps in the display's colour space, so that a cell that shows one again only shows an image.
/// Bitmaps can be drawn ahead on a queue of their own, so that a cell finds its bitmap ready.
enum SpotGlyphPicture {
    static let scale: CGFloat = 2

    private final class Bitmap: @unchecked Sendable {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    nonisolated(unsafe) private static let bitmaps: NSCache<NSString, Bitmap> = {
        let cache = NSCache<NSString, Bitmap>()
        cache.countLimit = 3000
        return cache
    }()

    private static let drawing = DispatchQueue(label: "openspot.glyphs", qos: .userInitiated)

    /// The bitmap of a colour emoji in a square of this side, or nil for a glyph drawn as text in the ink colour.
    static func image(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard isColour(glyph) else { return nil }
        let key = key(glyph, side: side, fontSize: fontSize)
        if let bitmap = bitmaps.object(forKey: key) { return bitmap.image }
        guard let image = draw(glyph, side: side, fontSize: fontSize) else { return nil }
        bitmaps.setObject(Bitmap(image), forKey: key)
        return image
    }

    /// Draws the bitmaps of these glyphs in the background, in order, and skips each that is drawn already.
    static func prepare(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        drawing.async {
            for glyph in glyphs where isColour(glyph) {
                let key = key(glyph, side: side, fontSize: fontSize)
                guard bitmaps.object(forKey: key) == nil, let image = draw(glyph, side: side, fontSize: fontSize) else { continue }
                bitmaps.setObject(Bitmap(image), forKey: key)
            }
        }
    }

    private static func isColour(_ glyph: String) -> Bool {
        glyph.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0 == "\u{FE0F}" }
    }

    private static func key(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> NSString {
        "\(glyph)|\(side)|\(fontSize)" as NSString
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
