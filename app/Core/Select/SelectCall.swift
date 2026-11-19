import Foundation

enum SelectCall: NounCall {
    case item(String)

    static let noun = CommandNoun("select", group: .build, verbs: [
        CommandVerb("", "<item>", "Selects an item of the spot's sheet once the spot's next frame shows.", rule: CallRule(flags: .needsApp)) { words in
            words.one.map(Self.item)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .item(let id) = self else { return nil }
        return SpotEffect.select(id).work(in: context, name: "select \(id)")
    }
}
