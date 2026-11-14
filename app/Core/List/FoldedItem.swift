import Foundation

struct FoldedItem {
    let title: FoldedText
    let subtitle: FoldedText?
    let keywords: SearchIndex.Texts
    let glyph: String?
    let letterBits: UInt64

    static func plain(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0 != "\u{FE0F}" && $0 != "\u{FE0E}" }))
    }
}
