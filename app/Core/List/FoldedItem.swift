import Foundation

/// One item of a search index, read in place: its folded title, subtitle and keywords, its glyph and its letters.
struct FoldedItem {
    let title: FoldedText
    let subtitle: FoldedText?
    let keywords: SearchIndex.Texts
    let glyph: String?
    /// One bit for each letter in its title, subtitle and keywords, so that a search skips an item that lacks a letter.
    let letterBits: UInt64

    /// Text with no mark that asks for a picture or a text form, so that both forms of a glyph are equal.
    static func plain(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0 != "\u{FE0F}" && $0 != "\u{FE0E}" }))
    }
}
