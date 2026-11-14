import Foundation

public struct GlyphBook: Equatable, Sendable {
    public static let scale = 2.0
    public static let fileExtension = ".glyphs"

    public let glyphs: [String]
    public let side: Double
    public let fontSize: Double
    private let places: [String: Int]

    public init(glyphs: [String], side: Double, fontSize: Double) {
        var places: [String: Int] = [:]
        var kept: [String] = []
        for glyph in glyphs where places[glyph] == nil && !glyph.contains(where: \.isNewline) {
            places[glyph] = kept.count
            kept.append(glyph)
        }
        self.glyphs = kept
        self.side = side
        self.fontSize = fontSize
        self.places = places
    }

    public var pixels: Int {
        Int((side * Self.scale).rounded(.up))
    }

    public var tileBytes: Int {
        pixels * pixels * 4
    }

    public var fileBytes: Int {
        glyphs.count * tileBytes
    }

    public func offset(of glyph: String) -> Int? {
        places[glyph].map { $0 * tileBytes }
    }

    public func name(system: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(side)|\(fontSize)|\(Self.scale)|\(system)\n\(glyphs.joined(separator: "\n"))".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(format: "%016llx", hash) + Self.fileExtension
    }

    public static func folder(in cache: URL = AppCache.folder()) -> URL {
        cache.appendingPathComponent("glyphs", isDirectory: true)
    }
}
