import Foundation

/// The keywords of the glyphs, read once and kept across calls of `openspot emoji` and `openspot symbols`.
final class GlyphKeywordCache: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: GlyphKeywords?

    func keywords() -> GlyphKeywords {
        lock.withLock {
            let keywords = kept ?? GlyphKeywords()
            kept = keywords
            return keywords
        }
    }
}
