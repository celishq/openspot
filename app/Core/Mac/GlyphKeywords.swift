import Foundation

/// The CLDR keywords of each emoji and symbol, in the first language of the Mac that has them, read from the xz files that
/// the app holds. A glyph with no keywords, or a folder with no files, gives none.
public struct GlyphKeywords: Sendable {
    /// The folder in the app, found from the real executable, so that the `openspot` command, a link to it, finds it too.
    public static let standardFolder = Bundle.main.executableURL?.resolvingSymlinksInPath()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Keywords")

    private static let tones: ClosedRange<UInt32> = 0x1F3FB...0x1F3FF
    private static let marks: Set<UInt32> = [0xFE0E, 0xFE0F]

    private let words: [String: [String]]

    public init(folder: URL? = standardFolder, languages: [String] = Locale.preferredLanguages) {
        words = folder.flatMap { folder in
            LanguageCodes(languages: languages).all.lazy
                .compactMap { try? (Data(contentsOf: folder.appendingPathComponent("\($0).tsv.xz")) as NSData).decompressed(using: .lzma) }
                .first
                .map { String(decoding: $0 as Data, as: UTF8.self) }
        }.map(Self.read) ?? [:]
    }

    /// The keywords of a glyph, found by its form with no skin tone and no presentation mark.
    public func of(_ glyph: String) -> [String] {
        let base = glyph.unicodeScalars.filter { !Self.tones.contains($0.value) && !Self.marks.contains($0.value) }
        return words[String(String.UnicodeScalarView(base))] ?? []
    }

    private static func read(_ text: String) -> [String: [String]] {
        var words: [String: [String]] = [:]
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t").map(String.init)
            guard let glyph = fields.first else { continue }
            words[glyph] = Array(fields.dropFirst())
        }
        return words
    }
}
