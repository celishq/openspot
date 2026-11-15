import Foundation

struct SymbolsCalls {
    let keywords: GlyphKeywordCache

    func rows() -> CommandAPI.Work {
        CommandAnswer.work { [keywords] in try SymbolCatalog(keywords: keywords.keywords()).rows() }
    }
}
