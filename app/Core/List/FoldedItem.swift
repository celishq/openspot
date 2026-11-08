import Foundation

/// An item with its texts folded for search, made once so that each search reads them as they are.
struct FoldedItem: Equatable, Sendable {
    let item: SpotItem
    let title: FoldedText
    let subtitle: FoldedText?
    let keywords: [FoldedText]
    let glyph: String?

    init(_ item: SpotItem) {
        self.item = item
        title = FoldedText(item.title)
        subtitle = item.subtitle.map(FoldedText.init)
        keywords = item.keywords.map(FoldedText.init)
        glyph = item.glyph.map(Self.plain)
    }

    /// Text with no mark that asks for a picture or a text form, so that both forms of a glyph are equal.
    static func plain(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0 != "\u{FE0F}" && $0 != "\u{FE0E}" }))
    }
}
