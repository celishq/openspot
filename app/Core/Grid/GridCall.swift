import Foundation

enum GridCall: NounCall {
    case edit

    static let noun = CommandNoun("grid", group: .app, verbs: [
        CommandVerb("edit", "", "Opens the panel in Edit Spots, to arrange the grid.", rule: CallRule(read: .changes("opens the panel"))) { $0.none ? Self.edit : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        SpotCalls(context).editGrid()
    }
}
