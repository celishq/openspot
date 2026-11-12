import Foundation

/// The call of `openspot emoji`: each emoji as a row, with its keywords.
struct EmojiCalls {
    let keywords: GlyphKeywordCache

    func rows(tone: EmojiCatalog.Tone) -> CommandAPI.Work {
        CommandAnswer.work { [keywords] in try EmojiCatalog(keywords: keywords.keywords()).rows(tone: tone) }
    }
}
