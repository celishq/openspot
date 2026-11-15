import Foundation

enum SymbolsCall: NounCall {
    case rows

    static let noun = CommandNoun("symbols", verbs: [
        CommandVerb("", "", "Prints each symbol of the Character Viewer as a row, with its name and section.") { $0.none ? Self.rows : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        SymbolsCalls(keywords: context.keywords).rows()
    }
}
