import Foundation

public struct GlyphKeywords: Sendable {
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

    public func of(_ glyph: String) -> [String] {
        let base = glyph.unicodeScalars.filter { !Self.tones.contains($0.value) && !Self.marks.contains($0.value) }
        return words[String(String.UnicodeScalarView(base))] ?? []
    }

    func field(of glyph: String) -> [TextBlock.Field] {
        let words = of(glyph)
        return words.isEmpty ? [] : [.init(key: "keywords", value: words.joined(separator: ", "))]
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
