import Foundation

enum TimerCall: NounCall {
    case add(at: String, words: [String])
    case remove(String)
    case list

    static let noun = CommandNoun("timer", group: .build, verbs: [
        CommandVerb("add", "<time> <action> [input...]", "Calls the action at the time, an ISO 8601 time such as 2026-11-20T08:00:00+01:00, with each input as <name>=<value>, even when the panel is closed, or keeps a timer that never comes due for `someday`. Prints the timer's id.", rule: CallRule(use: .timer, used: "added a timer", flags: .needsApp)) { words in
            guard let time = words.rest.first else { return nil }
            return Self.add(at: time, words: Array(words.rest.dropFirst()))
        },
        CommandVerb("remove", "<id>", "Removes a timer of the spot.", rule: CallRule(use: .timer, used: "removed a timer", flags: .needsApp)) { $0.one.map(Self.remove) },
        CommandVerb("list", "", "Prints each timer of the spot as an item: its id, its action as the title, its time in `at`, and each input as `input.<name>`.", rule: CallRule(use: .timer, used: "listed its timers")) { $0.none ? Self.list : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard let runs = context.runs else { return CommandAnswer.notRunning("timer") }
        guard let caller = context.caller else {
            return { CommandAnswer(errors: "`openspot timer` runs only from a spot, since a timer calls the spot that added it.\n", code: 1) }
        }
        let spot = caller.id
        switch self {
        case .add(let text, let words):
            let time = SpotTimer.time(of: text)
            guard time != nil || text == SpotTimer.someday else {
                return { CommandAnswer(errors: "`\(text)` is not a time. Write an ISO 8601 time with its offset, such as 2026-11-20T08:00:00+01:00.\n", code: 1) }
            }
            let timer: SpotTimer.Call
            do {
                timer = try SpotTimer.Call(words, of: caller)
            } catch {
                return { CommandAnswer(errors: "\((error as? SpotError)?.reason ?? error.localizedDescription)\n", code: 2) }
            }
            return {
                switch await runs.addTimer(at: time, call: timer, of: spot) {
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
        }
    }
}
