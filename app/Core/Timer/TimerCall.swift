import Foundation

enum TimerCall: NounCall {
    case add(at: String, value: String?)
    case remove(String)
    case list
    case pick

    static let noun = CommandNoun("timer", group: .build, verbs: [
        CommandVerb("add", "<time> [value]", "Calls the spot with `due <id>` at the time, an ISO 8601 time such as 2026-11-20T08:00:00+01:00, even when the panel is closed. Prints the timer's id.", rule: CallRule(use: .timer, used: "added a timer", flags: .needsApp)) { words in
            guard (1...2).contains(words.rest.count) else { return nil }
            return Self.add(at: words.rest[0], value: words.rest.count > 1 ? words.rest[1] : nil)
        },
        CommandVerb("remove", "<id>", "Removes a timer of the spot.", rule: CallRule(use: .timer, used: "removed a timer", flags: .needsApp)) { $0.one.map(Self.remove) },
        CommandVerb("pick", "", "Opens the snooze sheet and waits. Prints the time of the tile the person picks, or `someday`, or exits 1 when the sheet closes with no pick.", rule: CallRule(use: .timer, used: "picked a time", inShow: .waits, flags: .needsApp)) { $0.none ? Self.pick : nil },
        CommandVerb("list", "", "Prints each timer of the spot as an item: its id, its value as the title, and its time in `at`.", rule: CallRule(use: .timer, used: "listed its timers", flags: .needsApp)) { $0.none ? Self.list : nil }
    ])

    static let picker = "openspot/snooze"

    func work(in context: CallContext) -> CommandAPI.Work? {
        if case .pick = self { return SpotCalls(context).ask(Self.picker) }
        guard let runs = context.runs else { return CommandAnswer.notRunning("timer") }
        guard let spot = context.caller?.id else {
            return { CommandAnswer(errors: "`openspot timer` runs only from a spot, since a timer calls the spot that added it.\n", code: 1) }
        }
        switch self {
        case .add(let text, let value):
            guard let time = SpotTimer.time(of: text) else {
                return { CommandAnswer(errors: "`\(text)` is not a time. Write an ISO 8601 time with its offset, such as 2026-11-20T08:00:00+01:00.\n", code: 1) }
            }
            return {
                switch await runs.addTimer(at: time, value: value, of: spot) {
                case .success(let id): CommandAnswer(output: id + "\n")
                case .failure(let error): CommandAnswer(failure: error)
                }
            }
        case .remove(let id):
            return {
                await runs.removeTimer(id, of: spot) ? CommandAnswer() : CommandAnswer(errors: "The spot has no timer `\(id)`. `openspot timer list` prints its timers.\n", code: 1)
            }
        case .list:
            return { CommandAnswer(output: await runs.timers(of: spot).map(\.block).joined(separator: "\n")) }
        case .pick:
            return nil
        }
    }
}
