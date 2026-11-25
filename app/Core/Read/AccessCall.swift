import Foundation

enum AccessCall: NounCall {
    case list
    case ask(String)
    case grant(end: Bool)

    static let noun = CommandNoun("access", group: .mac, verbs: [
        CommandVerb(
            "list", "", "Prints an item=<id> record for each macOS access that a spot can need, with title=, access=, the spots= that are on and need it for a call they make, and maybe= those that need it only for some forms of a call. Then it prints app=, path= and access= for each app that Openspot reads. An access is allowed, denied, unasked, or unknown, as for an app that is closed. The record of the selected text has app=accessibility.",
            rule: ReadSources.rule
        ) { $0.none ? Self.list : nil },
        CommandVerb(
            "ask", "<app|accessibility>", "Asks macOS for Openspot's access to the app, or to Accessibility, when the person has not chosen yet, and prints its record.",
            rule: CallRule(use: .read, used: "asked for access to read", inShow: .waits, flags: .needsApp)
        ) { $0.one.map(Self.ask) },
        CommandVerb(
            "grant", "[--end]", "Prints the guided grant that runs as one block: item=grant, the spot=, its steps=, the step= it waits on with the place= of its switch in System Settings, the steps it is done= with, and restart=true when the step needs Openspot to start again. It prints nothing when none runs. --end ends it.",
            rule: CallRule(use: .spots, used: "read the guided grant", flags: .needsApp)
        ) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            return Self.grant(end: fit.has("--end"))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let config = context.places.config
        return switch self {
        case .list: list(in: context)
        case .grant(let end): grant(end: end, in: context)
        case .ask(let app): ReadSources.work(in: context, asks: true) { sources, _ in await sources.access(of: app, browsers: config.read().browsers, asks: true) }
        }
    }

    private func grant(end: Bool, in context: CallContext) -> CommandAPI.Work {
        guard let app = context.app else { return CommandAnswer.notRunning("access grant") }
        return CommandAnswer.work {
            if end { await app.endGrant() }
            return await app.grant()?.block.text ?? ""
        }
    }

    private func list(in context: CallContext) -> CommandAPI.Work {
        let api = context.api
        return ReadSources.work(in: context, asks: false) { _, _ in
            let read = try await api.accessList()
            return read.list.blocks + read.apps
        }
    }
}
