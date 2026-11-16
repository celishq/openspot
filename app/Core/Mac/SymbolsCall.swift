import Foundation

enum SymbolsCall: NounCall {
    case rows

    static let noun = CommandNoun("symbols", group: .mac, verbs: [
        CommandVerb("", "", "Prints each symbol of the Character Viewer as a row, with its name and section.", rule: CallRule(flags: .pure)) { $0.none ? Self.rows : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        CommandAnswer.work { try SymbolCatalog().rows() }
    }
}
