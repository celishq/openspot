import Foundation

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
