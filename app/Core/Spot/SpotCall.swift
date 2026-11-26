import Foundation

public enum SpotCall: NounCall {
    case new(name: String, starter: SpotStarter)
    case run(id: String, arguments: [String])
    case log(String)
    case actions(String?)
    case stats(days: Int, spot: String?, format: Stats.Form, byVersion: Bool = false)
    case show(String)
    case list(core: Bool, form: PrintForm)
    case add(String?, isConfirmed: Bool)
    case remove(String)
    case open(String)
    case push(String, route: String?, title: String?, replace: Bool)
    case pop(String, all: Bool)
    case choose(String)
    case act(CardAct, String)
    case review(String)

    private static let folder = "changes your spots folder"
    private static let panel = "opens the panel"
    private static let window = "opens a window"

    static let noun = CommandNoun("spot", group: .build, verbs: [
        CommandVerb("new", "<name> [--from kind]", "Writes a working spot to change. A kind is button, list, number or form.", rule: CallRule(use: .spots, used: "wrote a new spot")) { words in
            guard let fit = words.fit, fit.rest.count == 1, let starter = fit.value("--from").map { SpotStarter(rawValue: $0) } ?? .button else { return nil }
            return Self.new(name: fit.rest[0], starter: starter)
        },
        CommandVerb("run", "<id> [call] [value]...", "Makes one call of a spot as the app does, and prints all that it prints. For a spot with [actions] or [on], the call names a handler and each word after it is an input, <name>=<value>, checked as a call checks it, and the spot's bindings work as in a run.", rule: CallRule(use: .spots, used: "ran a spot", flags: .startsScripts)) { words in
            words.rest.first.map { Self.run(id: $0, arguments: Array(words.rest.dropFirst())) }
        },
        CommandVerb("actions", "[id]", "Prints each action of a spot, or of every spot, and each command of its uses, with their inputs and outputs as JSON Schema.") { words in
            words.fit.flatMap { $0.rest.count <= 1 ? Self.actions($0.rest.first) : nil }
        },
        CommandVerb("log", "<id>", "Prints the last calls that the app made to a spot.", rule: CallRule(use: .spots, used: "read the calls of a spot")) { $0.one.map(Self.log) },
        CommandVerb(
            "stats", "[--days n] [--spot id] [--by version] [--json | --openmetrics]",
            "Prints what each spot cost and used today, or over the last n days: a row for each spot with its runs, failures, CPU time, disk bytes, wakeups, each call that needs a use and its last fault, then a use block for each such call. --by version prints a row for each version of a spot. --json prints the days, and --openmetrics each counter in OpenMetrics text."
        ) { $0.fit.flatMap(stats) },
        CommandVerb(
            "list", "[--core] [--json]",
            "Prints an item, an item=<id> block, for each spot that the app loads, with a button=<id> or field=<id> block for each of its own. --core prints each spot that comes with the app, whether a spot of your spots folder takes its place, and its uses. --json prints them as JSON, with their keys."
        ) { words in
            words.fit.flatMap { $0.rest.isEmpty ? Self.list(core: $0.has("--core"), form: $0.form) : nil }
        },
        CommandVerb(
            "add", "[git url | folder | file.spot] [--yes]",
            "Puts a spot in the spots folder, a git one at its newest commit, and records it in spots.lock. A source that spots.lock has already updates its spot. With no source, it adds each spot of spots.lock that is missing, at its commit. An update that adds a use needs --yes.",
            rule: CallRule(use: .spots, used: "added a spot", inShow: .changes(folder))
        ) { words in
            guard let fit = words.fit, fit.rest.count <= 1 else { return nil }
            return Self.add(fit.rest.first, isConfirmed: fit.has("--yes"))
        },
        CommandVerb("remove", "<id>", "Moves a spot that spot add or store get added to the Trash, and drops it from spots.lock. Its data stays.", rule: CallRule(use: .spots, used: "removed a spot", inShow: .changes(folder))) { $0.one.map(Self.remove) },
        CommandVerb("open", "<id> [--select]", "Opens the panel on a spot, as a new flow. --select only selects its card on the grid.", rule: CallRule(inShow: .changes(panel), flags: .needsApp)) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return fit.has("--select") ? Self.show(fit.rest[0]) : Self.open(fit.rest[0])
        },
        CommandVerb("push", "<id> [page] [--replace] [--title <words>]", "Pushes a spot, or a page of it, over the flow that shows, or opens the panel on it when no sheet shows.", rule: CallRule(inShow: .changes(panel))) { $0.fit.flatMap(push) },
        CommandVerb("pop", "<id> [--all]", "Goes back one sheet of a spot that shows, or to its first sheet.", rule: CallRule(inShow: .changes("moves the panel"))) { words in
            guard let fit = words.fit, fit.rest.count == 1 else { return nil }
            return Self.pop(fit.rest[0], all: fit.has("--all"))
        },
        CommandVerb("choose", "<id>", "Asks for files and drops them on a spot that takes them.", rule: CallRule(inShow: .changes(window))) { $0.one.map(Self.choose) },
        act(.settings, "Opens the Settings of a spot, as the row of a card's menu does.", rule: CallRule(inShow: .changes(window))),
        act(.edit, "Opens the file of a spot to edit, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "opened the file of a spot", inShow: .changes(window))),
        act(.prompt, "Copies a prompt to change a spot, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "copied a prompt to change a spot", inShow: .changes(window))),
        act(.share, "Shares a spot, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "shared a spot", inShow: .changes(window))),
        act(.delete, "Moves the folder of a spot to the Trash and keeps its data, as Remove in a card's menu does.", rule: CallRule(use: .spots, used: "deleted a spot", inShow: .changes(folder))),
        CommandVerb("review", "<id>", "Shows the whole text of a spot that comes with the app, and what of it runs by itself. For a spot of a store, opens its page in the Store, where Install shows the same review.", rule: CallRule(inShow: .changes(panel), flags: .needsApp)) { $0.one.map(Self.review) }
    ])

    private static func act(_ act: CardAct, _ about: String, rule: CallRule) -> CommandVerb {
        CommandVerb(act.rawValue, "<id>", about, rule: rule) { words in words.one.map { Self.act(act, $0) } }
    }

    private static func stats(_ words: CommandForm.Words) -> SpotCall? {
        guard words.rest.isEmpty, words.value("--by").map({ $0 == "version" }) ?? true else { return nil }
        guard let days = words.value("--days").map({ Int($0).flatMap { $0 > 0 ? min($0, StatsLog.keptDays) : nil } }) ?? 1 else { return nil }
        let isMetrics = words.has(Stats.Form.metricsWord)
        guard !(isMetrics && words.form == .json) else { return nil }
        return .stats(days: days, spot: words.value(CallWords.spotWord), format: isMetrics ? .metrics : words.form == .json ? .json : .frame, byVersion: words.has("--by"))
    }

    private static func push(_ words: CommandForm.Words) -> SpotCall? {
        guard let id = words.rest.first, words.rest.count <= 2 else { return nil }
        return .push(id, route: words.rest.dropFirst().first, title: words.value("--title"), replace: words.has("--replace"))
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let spots = SpotCalls(context)
        return switch self {
        case .new(let name, let starter): spots.new(name, from: starter)
        case .run(let id, let arguments): spots.run(id, arguments, input: context.request.isPiped ? context.input : nil, careful: context.careful, output: context.output)
        case .log(let id): spots.log(id)
        case .actions(let id): spots.actions(id)
        case .stats(let days, let spot, let format, let byVersion): spots.stats(days: days, spot: spot, format: format, byVersion: byVersion)
        case .show(let id): spots.show(id)
        case .list(let core, let form): spots.list(core: core, form: form)
        case .add(let source?, let isConfirmed): spots.add(source, isConfirmed: isConfirmed)
        case .add(nil, let isConfirmed): spots.restore(isConfirmed: isConfirmed)
        case .remove(let id): spots.remove(id)
        case .open(let id): spots.open(id)
        case .push(let id, let route, let title, let replace): spots.push(id, route: route, title: title, replace: replace)
        case .pop(let id, let all): spots.pop(id, all: all)
        case .choose(let id): spots.choose(for: id)
        case .act(let act, let id): spots.act(act, id)
        case .review(let id): spots.review(id)
        }
    }
}
