import Foundation

enum AccessCall: NounCall {
    case list
    case ask(String)
    case grant(String?, end: Bool)

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
            "grant", "[id] [--end]", "With a spot, opens Settings at it and walks you through each macOS access that it lacks, one at a time, beside System Settings. With none, it prints the guided grant that runs as one block: item=grant, the spot=, its steps=, the step= it waits on with the place= of its switch in System Settings, the steps it is done= with, and restart=true when the step needs Openspot to start again. It prints nothing when none runs. --end ends it.",
            rule: CallRule(use: .spots, used: "used the guided grant", flags: .needsApp)
        ) { words in
            guard let fit = words.fit, fit.rest.count <= 1, fit.rest.isEmpty || !fit.has("--end") else { return nil }
            return Self.grant(fit.rest.first, end: fit.has("--end"))
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let config = context.places.config
        return switch self {
        case .list: list(in: context)
        case .grant(let spot?, _): grant(spot, in: context)
        case .grant(nil, let end): grant(end: end, in: context)
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

    private func grant(_ id: String, in context: CallContext) -> CommandAPI.Work {
        guard let app = context.app else { return CommandAnswer.notRunning("access grant \(id)") }
        let (places, mac, access, runs) = (context.places, context.mac, context.api.access, context.runs)
        return CommandAnswer.work {
            let config = places.config.read()
            guard let spot = try places.folder(config).scan().scripts.first(where: { $0.id == id }) else {
                throw SpotError.failed(1, "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.")
            }
            let statuses = await access.read(from: mac, browsers: config.browsers).statuses
            let last = (runs?.usage.lastUses ?? StatsLog.readLastUses(in: places.stats))[id] ?? [:]
            let needs = SpotStanding(spot, statuses: statuses, last: last, refused: [:]).missing
            guard !needs.isEmpty else { return "\(spot.name) has each macOS access it needs.\n" }
            guard await app.grant(id, needs: needs) else { throw SpotError.failed(1, "Openspot has no Settings to walk you through. Open Settings, then run this again.") }
            let titles = AccessGrant(spot: id, steps: needs).steps.map(\.title)
            return "Settings walks you through \(titles.count > 1 ? titles.dropLast().joined(separator: ", ") + " and " + titles[titles.count - 1] : titles.first ?? "").\n"
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
