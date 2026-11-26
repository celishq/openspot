import Foundation

public enum PlaygroundCommand: NounCall {
    case open(String?)

    static let noun = CommandNoun("playground", group: .build, verbs: [
        CommandVerb("open", "[file]", "Opens the playground: a spot that you type or a file, its live sheet and card, and each call that it gets with what it printed.", rule: CallRule(flags: .startsScripts)) { words in
            words.rest.count <= 1 ? Self.open(words.rest.first) : nil
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .open(let path) = self else { return nil }
        return PlaygroundCalls(folder: context.folder, app: context.app).open(path)
    }
}
