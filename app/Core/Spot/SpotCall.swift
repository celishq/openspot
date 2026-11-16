import Foundation

public enum SpotCall: NounCall {
    case new(name: String, starter: SpotStarter)
    case run(id: String, arguments: [String])
    case log(String)
    case stats(days: Int, spot: String?, format: StatsReport.Format)
    case show(String)
    case list(core: Bool, form: PrintForm)
    case add(String?, isConfirmed: Bool)
    case remove(String)
    case open(String)
    case push(String, page: String?, title: String?, replace: Bool)
    case pop(String, all: Bool)
    case choose(String)
    case act(CardAct, String)
    case review(String)

    private static let folder = "changes your spots folder"
    private static let panel = "opens the panel"
    private static let window = "opens a window"

    static let noun = CommandNoun("spot", group: .build, verbs: [
        CommandVerb("new", "<name> [--from kind]", "Writes a working spot to change. A kind is button, list, number or form.", rule: CallRule(use: .spots, used: "wrote a new spot")) { words in
            let rest = words.rest
            if rest.count == 1 { return Self.new(name: rest[0], starter: .button) }
            guard rest.count == 3, rest[1] == "--from", let starter = SpotStarter(rawValue: rest[2]) else { return nil }
            return Self.new(name: rest[0], starter: starter)
        },
        CommandVerb("run", "<id> [call] [value]...", "Makes one call of a spot as the app does, and prints all that it prints.", rule: CallRule(use: .spots, used: "ran a spot", flags: .startsScripts)) { words in
            words.rest.first.map { Self.run(id: $0, arguments: Array(words.rest.dropFirst())) }
        },
        CommandVerb("log", "<id>", "Prints the last calls that the app made to a spot.", rule: CallRule(use: .spots, used: "read the calls of a spot")) { $0.one.map(Self.log) },
        CommandVerb(
            "stats", "[--days n] [--spot id] [--json]",
            "Prints what each spot cost and used today, or over the last n days: a row for each spot with its runs, failures, CPU time, disk bytes, wakeups, each call that needs a use and its last fault, then a use block for each such call. --json prints the days."
        ) { stats($0.rest) },
        CommandVerb("show", "<id>", "Opens the panel with the spot selected.", rule: CallRule(read: .changes(panel), flags: .needsApp)) { $0.one.map(Self.show) },
        CommandVerb(
            "list", "[--core] [--json]",
            "Prints a spot=<id> block for each spot that the app loads, with a button=<id> or field=<id> block for each of its own. --core prints each spot that comes with the app, and whether it is on. --json prints them as JSON, with their keys."
        ) { words in
            words.options(["--core", PrintForm.jsonWord]).map { Self.list(core: $0.contains("--core"), form: $0.contains(PrintForm.jsonWord) ? .json : .frame) }
        },
        CommandVerb(
            "add", "[git url | folder | file.spot] [--yes]",
            "Puts a spot in the spots folder, a git one at its newest commit, and records it in spots.lock. A source that spots.lock has already updates its spot. With no source, it adds each spot of spots.lock that is missing, at its commit. An update that adds a use needs --yes.",
            rule: CallRule(use: .spots, used: "added a spot", read: .changes(folder))
        ) { words in
            let sources = words.rest.filter { $0 != "--yes" }
            guard sources.count <= 1, words.rest.count - sources.count <= 1 else { return nil }
            return Self.add(sources.first, isConfirmed: sources.count < words.rest.count)
        },
        CommandVerb("remove", "<id>", "Moves a spot that spot add added to the Trash, and drops it from spots.lock.", rule: CallRule(use: .spots, used: "removed a spot", read: .changes(folder))) { $0.one.map(Self.remove) },
        CommandVerb("open", "<id>", "Opens the panel on a spot, as a new flow.", rule: CallRule(read: .changes(panel), flags: .needsApp)) { $0.one.map(Self.open) },
        CommandVerb("push", "<id> [page] [--replace] [--title <words>]", "Pushes a spot, or a page of it, over the flow that shows.", rule: CallRule(read: .changes(panel))) { push($0.rest) },
        CommandVerb("pop", "<id> [--all]", "Goes back one sheet of a spot that shows, or to its first sheet.", rule: CallRule(read: .changes("moves the panel"))) { words in
            switch words.rest.count {
            case 1: Self.pop(words.rest[0], all: false)
            case 2 where words.rest[1] == "--all": Self.pop(words.rest[0], all: true)
            default: nil
            }
        },
        CommandVerb("choose", "<id>", "Asks for files and drops them on a spot that takes them.", rule: CallRule(read: .changes(window))) { $0.one.map(Self.choose) },
        act(.settings, "Opens the Settings of a spot, as the row of a card's menu does.", rule: CallRule(read: .changes(window))),
        act(.edit, "Opens the file of a spot to edit, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "opened the file of a spot", read: .changes(window))),
        act(.prompt, "Copies a prompt to change a spot, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "copied a prompt to change a spot", read: .changes(window))),
        act(.share, "Shares a spot, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "shared a spot", read: .changes(window))),
        act(.delete, "Deletes a spot, as the row of a card's menu does.", rule: CallRule(use: .spots, used: "deleted a spot", read: .changes(folder))),
        CommandVerb("review", "<id>", "Shows the whole text of a spot that comes with the app, and what of it runs by itself.", rule: CallRule(read: .changes(panel), flags: .needsApp)) { $0.one.map(Self.review) }
    ])

    private static func act(_ act: CardAct, _ about: String, rule: CallRule) -> CommandVerb {
        CommandVerb(act.rawValue, "<id>", about, rule: rule) { words in words.one.map { Self.act(act, $0) } }
    }

    private static func stats(_ words: [String]) -> SpotCall? {
        var days = 1
        var spot: String?
        var format = StatsReport.Format.frame
        var seen: Set<String> = []
        var index = 0
        while index < words.count {
            let word = words[index]
            guard seen.insert(word).inserted else { return nil }
            switch word {
            case "--days":
                guard index + 1 < words.count, let number = Int(words[index + 1]), number > 0 else { return nil }
                days = min(number, SpotUsage.keptDays)
                index += 1
            case CallWords.spotWord:
                guard index + 1 < words.count else { return nil }
                spot = words[index + 1]
                index += 1
            case PrintForm.jsonWord: format = .json
            default: return nil
            }
            index += 1
        }
        return .stats(days: days, spot: spot, format: format)
    }

    private static func push(_ words: [String]) -> SpotCall? {
        guard let id = words.first else { return nil }
        var page: String?
        var title: String?
        var replace = false
        var rest = words.dropFirst()
        while let word = rest.popFirst() {
            switch word {
            case "--replace": replace = true
            case "--title":
                guard let words = rest.popFirst() else { return nil }
                title = words
            case _ where page == nil && !word.hasPrefix("--"): page = word
            default: return nil
            }
        }
        return .push(id, page: page, title: title, replace: replace)
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let spots = SpotCalls(context)
        return switch self {
        case .new(let name, let starter): spots.new(name, from: starter)
        case .run(let id, let arguments): spots.run(id, arguments, input: context.request.isPiped ? context.input : nil, careful: context.careful, output: context.output)
        case .log(let id): spots.log(id)
        case .stats(let days, let spot, let format): spots.stats(days: days, spot: spot, format: format)
        case .show(let id): spots.show(id)
        case .list(let core, let form): spots.list(core: core, form: form)
        case .add(let source?, let isConfirmed): spots.add(source, isConfirmed: isConfirmed)
        case .add(nil, let isConfirmed): spots.restore(isConfirmed: isConfirmed)
        case .remove(let id): spots.remove(id)
        case .open(let id): spots.open(id)
        case .push(let id, let page, let title, let replace): spots.push(id, page: page, title: title, replace: replace)
        case .pop(let id, let all): spots.pop(id, all: all)
        case .choose(let id): spots.choose(for: id)
        case .act(let act, let id): spots.act(act, id)
        case .review(let id): spots.review(id)
        }
    }
}
