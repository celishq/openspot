import Foundation

enum GridCall: NounCall {
    case edit

    static let noun = CommandNoun("grid", group: .app, verbs: [
        CommandVerb("edit", "", "Opens Arrange, where you pin your spots to the grid and take them off.", rule: CallRule(inShow: .changes("opens the panel"))) { $0.none ? Self.edit : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        SpotCalls(context).editGrid()
    }
}
