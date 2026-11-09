import AppKit
import CoreText
import OpenspotCore
import Synchronization

/// Colour emoji as bitmaps in the display's colour space. A big list's emoji come from its picture book, which a helper
/// process drew once and the app maps from disk, so they cost the app no drawing and no memory of its own. Any other emoji
/// is drawn here once, and its bitmap can be drawn ahead on a queue of its own, so that a cell finds it ready.
enum SpotGlyphPicture {
    static let scale = CGFloat(GlyphBook.scale)
    /// The fewest colour glyphs that a list needs for a book. A list of fewer draws them here.
    private static let bookFloor = 100

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
    private static let binding = DispatchQueue(label: "openspot.glyph-books", qos: .utility)
    /// The book in use for each size, by its side and font size.
    private static let books = Mutex<[String: SpotGlyphBook]>([:])

    /// The bitmap of a colour emoji in a square of this side, or nil for a glyph drawn as text in the ink colour.
    static func image(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard isColour(glyph) else { return nil }
        let key = key(glyph, side: side, fontSize: fontSize)
        if let bitmap = bitmaps.object(forKey: key) { return bitmap.image }
        guard let image = book(side: side, fontSize: fontSize)?.image(of: glyph) ?? draw(glyph, side: side, fontSize: fontSize) else { return nil }
        keep(image, as: key)
        return image
    }

    /// Draws the bitmaps of these glyphs in the background, in order, and skips each that is drawn already or in the book.
    static func prepare(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        drawing.async {
            let book = book(side: side, fontSize: fontSize)
            for glyph in glyphs where isColour(glyph) && book?.layout.offset(of: glyph) == nil {
                let key = key(glyph, side: side, fontSize: fontSize)
                guard bitmaps.object(forKey: key) == nil, let image = draw(glyph, side: side, fontSize: fontSize) else { continue }
                keep(image, as: key)
            }
        }
    }

    /// Takes the book of a whole list's colour glyphs at this size: maps it when a helper drew it before, else has a helper
    /// draw it. A list with few colour glyphs gets none.
    static func bind(_ glyphs: [String], side: CGFloat, fontSize: CGFloat) {
        binding.async {
            let layout = GlyphBook(glyphs: glyphs.filter(isColour), side: Double(side), fontSize: Double(fontSize))
            let size = sizeKey(side: side, fontSize: fontSize)
            guard layout.glyphs.count >= bookFloor, books.withLock({ $0[size]?.layout }) != layout else { return }
            let file = GlyphBook.folder().appendingPathComponent(layout.name(system: ProcessInfo.processInfo.operatingSystemVersionString))
            guard let book = SpotGlyphBook.open(layout, at: file) ?? SpotGlyphBook.draw(layout, at: file) else { return }
            books.withLock { $0[size] = book }
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

    private static func book(side: CGFloat, fontSize: CGFloat) -> SpotGlyphBook? {
        books.withLock { $0[sizeKey(side: side, fontSize: fontSize)] }
    }

    /// Keeps a bitmap at the cost of its bytes, so that the cache holds a few screens of pictures and lets the oldest go.
    private static func keep(_ image: CGImage, as key: NSString) {
        bitmaps.setObject(Bitmap(image), forKey: key, cost: image.bytesPerRow * image.height)
    }

    private static func isColour(_ glyph: String) -> Bool {
        glyph.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0 == "\u{FE0F}" }
    }

    private static func key(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> NSString {
        "\(glyph)|\(sizeKey(side: side, fontSize: fontSize))" as NSString
    }

    private static func sizeKey(side: CGFloat, fontSize: CGFloat) -> String {
        "\(side)|\(fontSize)"
    }

    private static func draw(_ glyph: String, side: CGFloat, fontSize: CGFloat) -> CGImage? {
        guard let context = context(side: side) else { return nil }
        render(glyph, side: side, fontSize: fontSize, in: context)
        return context.makeImage()
    }
}
