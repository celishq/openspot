import AppKit
import CoreText
import OpenspotCore

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

    static func image(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard isColour(glyph) else { return nil }
        let key = key(glyph, side: side, fontSize: fontSize)
        if let bitmap = bitmaps.object(forKey: key) { return bitmap.image }
        guard let image = SpotGlyphShelf.book(side: side, fontSize: fontSize)?.image(of: glyph) ?? draw(glyph, side: side, fontSize: fontSize) else { return nil }
        keep(image, as: key)
        return image
    }

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

    static func context(side: CGFloat, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
        let pixels = Int((side * scale).rounded(.up))
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(data: data, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        return context
    }

    static func render(_ glyph: String, side: CGFloat, fontSize: CGFloat, in context: CGContext) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: glyph, attributes: [.font: NSFont.systemFont(ofSize: fontSize)]))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        context.textPosition = CGPoint(x: (side - width) / 2, y: (side - ascent - descent) / 2 + descent)
        CTLineDraw(line, context)
    }

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
