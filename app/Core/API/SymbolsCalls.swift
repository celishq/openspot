import Foundation

/// The call of `openspot symbols`: each symbol of the Character Viewer as a row, with its keywords.
struct SymbolsCalls {
    let keywords: GlyphKeywordCache

    func rows() -> CommandAPI.Work {
        CommandAnswer.work { [keywords] in try SymbolCatalog(keywords: keywords.keywords()).rows() }
    }
}
