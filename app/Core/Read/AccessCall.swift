import Foundation

enum AccessCall: NounCall {
    case list
    case ask(String)

    static let noun = CommandNoun("access", group: .mac, verbs: [
        CommandVerb(
            "list", "", "Prints app=, path= and access= for each app that Openspot reads: allowed, denied, unasked, or unknown while the app is closed. The record of the selected text has app=accessibility.",
            rule: ReadSources.rule
        ) { $0.none ? Self.list : nil },
        CommandVerb(
            "ask", "<bundle id or accessibility>", "Asks the person for Openspot's access to the app, or to Accessibility, when they have not chosen yet, and prints its record.",
            rule: CallRule(use: .read, used: "asked for access to read", inShow: .waits, flags: .needsApp)
        ) { $0.one.map(Self.ask) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        switch self {
        case .list: ReadSources.work(in: context, asks: false) { sources, _ in await sources.access() }
        case .ask(let app): ReadSources.work(in: context, asks: true) { sources, _ in await sources.access(of: app, asks: true) }
        }
    }
}
