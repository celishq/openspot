import Foundation

enum TimelineCall: NounCall {
    case add([String])
    case list(spot: String?, all: Bool, within: TimeInterval?, search: String?, after: String?, limit: Int?)
    case get(String)
    case forget(String)
    case restore(String)
    case keep(String)
    case pause(String)
    case resume

    private static let keys = AttachmentValue.Kind.allCases.map(\.rawValue) + notes
    private static let notes = ["title", "detail", "app", "icon", "key", "at"]
    private static let listForm = "[--spot id] [--all] [--within age] [--search words] [--after id] [--limit n]"

    static let noun = CommandNoun("timeline", group: .build, verbs: [
        CommandVerb(
            "add", "[input...]",
            "Adds an entry to the calling spot's timeline and prints its id: `text=`, `url=` or `file=` once for each file, with `title=`, the line under it in `detail=`, the app in `app=`, `icon=` as `icon` in spot.toml takes it, `key=`, which moves an entry of the same key to the top, and `at=`, an ISO 8601 time. A file up to 25 MB on the same disk is kept as a copy. With no input it takes the same lines on stdin, and adds nothing when they hold no value; a `peek=` block after them and the blocks under it are kept as the peek of the entry, up to 64 KB, with no button that lacks an `action=` and a copy of each picture. It works in a show.",
            rule: CallRule(use: .timeline, used: "added to its timeline")
        ) { Self.add($0.rest) },
        CommandVerb(
            "list", listForm,
            "Prints each entry of the calling spot's timeline, newest first, as an item with `spot`, `at`, its `kind` and its value. --spot names another spot's timeline and --all prints every timeline, which need `read`. --within keeps the entries of the age, such as 1d; --search the ones that hold each word, best match first; --after the ones after the entry of that id, for the next page; --limit the first n.",
            rule: CallRule(use: .timeline, used: "read its timeline")
        ) { words in
            guard let fit = words.fit, fit.rest.isEmpty else { return nil }
            let within = fit.value("--within").map { Manifest.Triggers.age(orSeconds: $0).flatMap { $0 > 0 ? $0 : nil } }
            guard within != .some(nil), fit.value("--limit").map({ Int($0).map { $0 > 0 } == true }) != false else { return nil }
            return Self.list(spot: fit.value(CallWords.spotWord), all: fit.has("--all"), within: within ?? nil, search: fit.value("--search"), after: fit.value("--after"), limit: fit.value("--limit").flatMap { Int($0) })
        },
        CommandVerb("get", "<id>", "Prints the whole value of the entry: its text, its link, or the path of each file on a line. Pipe it into `clipboard copy` to copy a text or a link.", rule: CallRule(use: .timeline, used: "read an entry")) { $0.one.map(Self.get) },
        CommandVerb("forget", "<id>", "Takes the entry out of the timeline. `openspot timeline restore` brings it back for 10 minutes.", rule: CallRule(use: .timeline, used: "forgot an entry")) { $0.one.map(Self.forget) },
        CommandVerb("restore", "<id>", "Brings back an entry that `openspot timeline forget` took out.", rule: CallRule(use: .timeline, used: "restored an entry")) { $0.one.map(Self.restore) },
        CommandVerb("keep", "<days>", "Keeps each entry for the days, 30 by default, and drops what is older.", rule: CallRule(use: .timeline, used: "changed how long the timeline keeps", onlyPerson: Self.personOnly)) { $0.one.map(Self.keep) },
        CommandVerb("pause", "<age>", "Adds nothing to any timeline for the age, such as 1h.", rule: CallRule(use: .timeline, used: "paused the timeline", onlyPerson: Self.personOnly)) { $0.one.map(Self.pause) },
        CommandVerb("resume", "", "Ends a pause of the timeline.", rule: CallRule(use: .timeline, used: "resumed the timeline", onlyPerson: Self.personOnly)) { $0.none ? Self.resume : nil },
    ])

    private static let personOnly = "cannot change the timeline of every spot. Only you can, in the Settings of Timeline or with `openspot timeline` in Terminal."


    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        var rule = rule
        switch self {
        case .add(let words) where words.isEmpty: rule.flags.insert(.readsInput)
        case .list(let other?, _, _, _, _, _) where other != spot: rule.use = .read
        case .list(_, true, _, _, _, _): rule.use = .read
        default: break
        }
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let runs = context.runs else { return CommandAnswer.notRunning("timeline") }
        guard let work = job(in: context, runs: runs) else { return nil }
        return {
            let answer = await work()
            await runs.timelineUsed()
            return answer
        }
    }

    private func job(in context: CallContext, runs: SpotRuns) -> CommandAPI.Work? {
        let caller = context.caller
        let timeline = runs.timeline
        switch self {
        case .add(let words):
            guard let caller else {
                return { CommandAnswer(errors: "`openspot timeline add` runs only from a spot, since an entry belongs to the spot that adds it.\n", code: 1) }
            }
            let spot = caller.id
            if !words.isEmpty {
                var fields: [TextBlock.Field] = []
                for word in words {
                    guard let split = word.firstIndex(of: "="), Self.keys.contains(String(word[..<split])) else {
                        return { CommandAnswer(errors: "`openspot timeline add` does not take \(word). Write text=, url= or file=, and title=, detail=, app=, icon=, key= or at=.\n", code: 2) }
                    }
                    fields.append(TextBlock.Field(key: String(word[..<split]), value: String(word[word.index(after: split)...])))
                }
                return Self.add(fields, of: spot, to: runs)
            }
            return {
                let blocks = TextBlock.blocks(in: await context.input())
                let fields = (blocks.first?.fields ?? []).filter { Self.keys.contains($0.key) }
                guard fields.contains(where: { !Self.notes.contains($0.key) }) else { return CommandAnswer() }
                return await Self.add(fields, of: spot, to: runs, peek: Self.peek(in: blocks.dropFirst()))()
            }
        case .list(let other, let all, let within, let search, let after, let limit):
            let spots: Set<String>? = all ? nil : other.map { [$0] } ?? caller.map { [$0.id] }
            let reader = caller?.id
            return {
                if let reader { timeline.note(reader: reader, of: spots) }
                let now = runs.clock.now()
                guard let entries = timeline.list(Timeline.Query(spots: spots, within: within ?? nil, text: search, after: after, limit: limit), at: now) else {
                    return CommandAnswer(errors: "The timeline has no entry `\(after ?? "")` to list after. Start again with no --after.\n", code: 1)
                }
                return CommandAnswer(output: entries.map(\.block).joined(separator: "\n"))
            }
        case .keep(let text):
            guard let days = Int(text), days > 0 else {
                return { CommandAnswer(errors: "`\(text)` is not a count of days. Write a whole number above 0, such as 30.\n", code: 2) }
            }
            return {
                timeline.keep(days: days, at: runs.clock.now())
                return CommandAnswer()
            }
        case .pause(let text):
            guard let age = Manifest.Triggers.age(orSeconds: text), age > 0 else {
                return { CommandAnswer(errors: "`\(text)` is not an age. Write seconds, or a number with s, m, h or d, such as 1h.\n", code: 2) }
            }
            return {
                let now = runs.clock.now()
                timeline.pause(until: now.addingTimeInterval(age), at: now)
                return CommandAnswer()
            }
        case .resume:
            return {
                timeline.pause(until: nil, at: runs.clock.now())
                return CommandAnswer()
            }
        case .get(let id):
            return {
                guard let found = timeline.entry(id), found.forgotten == nil, Self.reaches(found.spot, from: caller) else {
                    return CommandAnswer(errors: "The timeline has no entry `\(id)` that this spot can reach. `openspot timeline list` prints its entries.\n", code: 1)
                }
                switch found.kind {
                case .file: return CommandAnswer(output: found.files.map(\.path).joined(separator: "\n"))
                case .text, .url: return CommandAnswer(output: found.textFile.flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? found.value)
                }
            }
        case .forget(let id), .restore(let id):
            let isForget = if case .forget = self { true } else { false }
            return {
                let now = runs.clock.now()
                guard let found = timeline.entry(id), Self.reaches(found.spot, from: caller) else {
                    return CommandAnswer(errors: "The timeline has no entry `\(id)` that this spot can reach. `openspot timeline list` prints its entries.\n", code: 1)
                }
                guard (isForget ? timeline.forget(id, at: now) : timeline.restore(id)) != nil else {
                    return CommandAnswer(errors: isForget ? "The entry `\(id)` is already forgotten.\n" : "The entry `\(id)` is not forgotten, or was forgotten more than 10 minutes ago.\n", code: 1)
                }
                await runs.timelineChanged(found.spot, by: nil)
                return CommandAnswer()
            }
        }
    }

    private static func reaches(_ spot: String, from caller: Spot?) -> Bool {
        guard let caller else { return true }
        return caller.id == spot || caller.uses.contains(.read)
    }

    private static func peek(in blocks: ArraySlice<TextBlock>) -> [TextBlock] {
        guard let head = blocks.first, head.fields.first?.key == BlockKind.peek.word, let id = head.value(BlockKind.peek.word) else { return [] }
        var held: Set<String> = [id]
        var peek = [head]
        for block in blocks.dropFirst() {
            guard let parent = block.value(ViewNode.parentKey), held.contains(parent) else { break }
            if let own = block.fields.first?.value, !own.isEmpty { held.insert(own) }
            peek.append(block)
        }
        return peek
    }

    private static func add(_ fields: [TextBlock.Field], of spot: String, to runs: SpotRuns, peek: [TextBlock] = []) -> CommandAPI.Work {
        let note = { (key: String) in fields.last { $0.key == key }?.value }
        guard let (kind, values) = AttachmentValue.Kind.value(in: fields) else {
            return { CommandAnswer(errors: "`openspot timeline add` takes one kind of value: text=, url= or file= once for each file.\n", code: 2) }
        }
        guard values.allSatisfy({ !$0.isEmpty }) else {
            return { CommandAnswer(errors: "`openspot timeline add` takes a value that is not empty.\n", code: 2) }
        }
        var at: Date?
        if let text = note("at") {
            guard let time = SpotTimer.time(of: text) else {
                return { CommandAnswer(errors: "`\(text)` is not a time. Write an ISO 8601 time with its offset, such as 2026-11-20T08:00:00+01:00.\n", code: 2) }
            }
            at = time
        }
        let isOver = peek.map(\.text).joined(separator: "\n").utf8.count > Timeline.peekLimit
        let draft = Timeline.Draft(kind: kind, values: values, title: note("title"), app: note("app"), icon: note("icon"), detail: note("detail"), key: note("key"), at: at, peek: isOver ? [] : peek)
        let timeline = runs.timeline
        return {
            do {
                guard let entry = try timeline.add(draft, of: spot, at: runs.clock.now()) else { return CommandAnswer() }
                await runs.timelineChanged(spot, by: spot)
                guard !isOver else { return CommandAnswer(output: entry.id + "\n", errors: "The peek is over 64 KB, so the timeline keeps the entry without it.\n", code: 1) }
                return CommandAnswer(output: entry.id + "\n")
            } catch {
                return CommandAnswer(errors: "Openspot could not keep the entry: \(error.localizedDescription)\n", code: 1)
            }
        }
    }
}
