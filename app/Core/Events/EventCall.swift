import Foundation

enum EventCall: NounCall {
    case emit(name: String, value: String?)

    static let noun = CommandNoun("event", verbs: [
        CommandVerb("emit", "<name> [value]", "Raises an event in the running app, such as music.track. Each spot that lists it in its read reads, with the value in OPENSPOT_VALUE.", rule: CallRule(flags: .needsApp)) { words in
            guard let name = words.rest.first, words.rest.count <= 2 else { return nil }
            guard SpotEvent.isName(name) else { return CallFault.refused("`\(name)` is not an event. Name one with a dot, such as `music.track`.") }
            guard words.reason != name else {
                return CallFault.refused("`openspot event emit \(name)` runs in a read of `\(name)`, so it would read that spot again without end, and Openspot did not raise it. Raise it from an action, or raise another event.")
            }
            return Self.emit(name: name, value: words.rest.dropFirst().first)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .emit(let name, let value) = self else { return nil }
        return EventCalls(raise: context.raise).emit(name, value: value)
    }
}
