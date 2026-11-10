import AppKit
import CoreText
import OpenspotCore

/// Colour emoji as bitmaps in the display's colour space. A big list's emoji come from the book that the shelf holds for
/// their size, so they cost the app no drawing. Any other emoji is drawn here once. Each bitmap can be made ahead on a
/// queue of its own, so that a cell finds it ready.
enum SpotGlyphPicture {
    static let scale = CGFloat(GlyphBook.scale)

    private final class Bitmap: @unchecked Sendable {
        let image: CGImage

        init(_ image: CGImage) {
            self.image = image
        }
    }

    nonisolated(unsafe) private static let bitmaps: NSCache<NSString, Bitmap> = {
        let cache = NSCache<NSString, Bitmap>()
        cache.totalCostLimit = 4 << 20
        return cache
    }()

    private static let drawing = DispatchQueue(label: "openspot.glyphs", qos: .userInitiated)

    /// The bitmap of a colour emoji in a square of this side, or nil for a glyph drawn as text in the ink colour.
    static func image(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard isColour(glyph) else { return nil }
        let key = key(glyph, side: side, fontSize: fontSize)
        if let bitmap = bitmaps.object(forKey: key) { return bitmap.image }
        guard let image = SpotGlyphShelf.book(side: side, fontSize: fontSize)?.image(of: glyph) ?? draw(glyph, side: side, fontSize: fontSize) else { return nil }
        keep(image, as: key)
        return image
    }

    /// Makes the bitmaps of these glyphs in the background, in order, from the book or by drawing, and skips each that is
    /// ready, so that a cell reads no page of the book and draws nothing on the main thread.
    static func prepare(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        drawing.async {
            let book = SpotGlyphShelf.book(side: side, fontSize: fontSize)
            for glyph in glyphs where isColour(glyph) {
                let key = key(glyph, side: side, fontSize: fontSize)
                guard bitmaps.object(forKey: key) == nil,
                      let image = book?.image(of: glyph) ?? draw(glyph, side: side, fontSize: fontSize) else { continue }
                keep(image, as: key)
            }
        }
    }

    /// A context of a square of this side at the scale, which draws into `data` when it is given.
    static func context(side: CGFloat, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
        let pixels = Int((side * scale).rounded(.up))
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(data: data, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        return context
    }

    /// Draws a glyph in the middle of a context made by `context(side:data:)`.
    static func render(_ glyph: String, side: CGFloat, fontSize: CGFloat, in context: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [.font: NSFont.systemFont(ofSize: fontSize)]))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(x: (side - width) / 2, y: (side - ascent - descent) / 2 + descent)
        CTLineDraw(line, context)
    }

    /// Keeps a bitmap at the cost of its bytes, so that the cache holds a few screens of pictures and lets the oldest go.
    private static func keep(_ image: CGImage, as key: NSString) {
        bitmaps.setObject(Bitmap(image), forKey: key, cost: image.bytesPerRow * image.height)
    }

    static func isColour(_ glyph: String) -> Bool {
        glyph.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0 == "\u{FE0F}" }
    }

    private static func key(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> NSString {
        "\(glyph)|\(SpotGlyphShelf.sizeKey(side: side, fontSize: fontSize))" as NSString
    }

    private static func draw(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard let context = context(side: side) else { return nil }
        render(glyph, side: side, fontSize: fontSize, in: context)
        return context.makeImage()
    }
}
