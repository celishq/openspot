import Foundation

enum AccessCall: NounCall {
    case list
    case ask(String)

    static let noun = CommandNoun("access", group: .mac, verbs: [
        CommandVerb(
            "list", "", "Prints an item=<id> record for each macOS access that a spot can need, with title=, access=, the spots= that are on and need it for a call they make, and maybe= those that need it only for some forms of a call. Then it prints app=, path= and access= for each app that Openspot reads. An access is allowed, denied, unasked, or unknown, as for an app that is closed. The record of the selected text has app=accessibility.",
            rule: ReadSources.rule
        ) { $0.none ? Self.list : nil },
        CommandVerb(
            "ask", "<app|accessibility>", "Asks macOS for Openspot's access to the app, or to Accessibility, when the person has not chosen yet, and prints its record.",
            rule: CallRule(use: .read, used: "asked for access to read", inShow: .waits, flags: .needsApp)
        ) { $0.one.map(Self.ask) }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let config = context.places.config
        return switch self {
        case .list: list(in: context)
        case .ask(let app): ReadSources.work(in: context, asks: true) { sources, _ in await sources.access(of: app, browsers: config.read().browsers, asks: true) }
        }
    }

    private func list(in context: CallContext) -> CommandAPI.Work {
        let (kept, mac, places, runs) = (context.api.access, context.mac, context.places, context.runs)
        return ReadSources.work(in: context, asks: false) { _, _ in
            let config = places.config.read()
            let (statuses, apps) = await kept.read(from: mac, browsers: config.browsers)
            let last = runs?.usage.lastUses ?? StatsLog.readLastUses(in: places.stats)
            let spots = try places.folder(config).scan().scripts.map { spot in
                (id: spot.id, access: SpotAccess(spot, written: KeptCalls.shared.read(spot), made: Array((last[spot.id] ?? [:]).keys)))
            }
            return AccessList(statuses: statuses, spots: spots).blocks + apps
        }
    }
}
