import Foundation

struct EmojiCalls {
    let keywords: GlyphKeywordCache

    func rows(tone: EmojiCatalog.Tone) -> CommandAPI.Work {
        CommandAnswer.work { [keywords] in try EmojiCatalog(keywords: keywords.keywords()).rows(tone: tone) }
    }
}
