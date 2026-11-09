import Foundation

/// The layout of a picture book: colour glyphs drawn once at one size, tile after tile, in a file that the app maps from
/// disk. Each tile is a square of premultiplied RGBA bytes at twice the side. The file's name changes with its glyphs, its
/// sizes and the system, so a new set of emoji gets a new book.
public struct GlyphBook: Equatable, Sendable {
    public static let scale = 2.0
    public static let fileExtension = ".glyphs"

    public let glyphs: [String]
    public let side: Double
    public let fontSize: Double
    private let places: [String: Int]

    /// Keeps each glyph once, in its first place, and leaves out a glyph that breaks a line, which a helper reads as two.
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

    /// Where the tile of a glyph starts in the file, or nil for a glyph that the book does not hold.
    public func offset(of glyph: String) -> Int? {
        places[glyph].map { $0 * tileBytes }
    }

    /// The file name of the book on this system, from a stable hash of all that its pictures depend on.
    public func name(system: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(side)|\(fontSize)|\(Self.scale)|\(system)\n\(glyphs.joined(separator: "\n"))".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(format: "%016llx", hash) + Self.fileExtension
    }

    public static func folder(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        devState: String? = Bundle.main.object(forInfoDictionaryKey: "OpenspotDevState") as? String
    ) -> URL {
        AppCache.folder(environment: environment, home: home, devState: devState).appendingPathComponent("glyphs", isDirectory: true)
    }
}
