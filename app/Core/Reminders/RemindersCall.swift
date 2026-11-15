import Foundation

enum RemindersCall: NounCall {
    case due(days: Int, hidden: [String])
    case lists
    case add(words: String, isDry: Bool)
    case done(id: String, isDone: Bool)
    case show(id: String)

    private static let read = "read your reminders"
    private static let change = "changes your reminders"

    static let noun = CommandNoun("reminders", guide: "calendar", verbs: [
        CommandVerb("due", "[--days n] [--hide id]...", "Prints each open reminder that is late or due through the end of day n, and each one done today, as a row. --hide leaves out a list.", rule: CallRule(use: .calendar, used: read)) { words in
            CallWords.listing(words.rest).map { Self.due(days: $0.days, hidden: $0.hidden) }
        },
        CommandVerb("lists", "", "Prints each list of reminders as a row.", rule: CallRule(use: .calendar, used: read)) { $0.none ? Self.lists : nil },
        CommandVerb("add", "[--dry-run] <words>...", "Adds a reminder from words such as Call mom tomorrow 9am, and prints its row. --dry-run prints the row and adds nothing.", rule: CallRule(use: .calendar, used: "added a reminder", read: .changes(change))) { words in
            CallWords.adding(words.rest).map { Self.add(words: $0.words, isDry: $0.isDry) }
        },
        CommandVerb("done", "<id> [true|false]", "Ticks a reminder, or with false opens it again.", rule: CallRule(use: .calendar, used: "changed a reminder", read: .changes(change))) { words in
            switch words.rest.count {
            case 1: Self.done(id: words.rest[0], isDone: true)
            case 2 where ["true", "false"].contains(words.rest[1]): Self.done(id: words.rest[0], isDone: words.rest[1] == "true")
            default: nil
            }
        },
        CommandVerb("show", "<id>", "Opens Reminders on the reminder of a row.", rule: CallRule(use: .calendar, used: "opened Reminders", read: .changes("opens Reminders"))) { $0.one.map { Self.show(id: $0) } }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard case .add(_, true) = self else { return rule }
        var rule = rule
        rule.read = .free
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let reminders = context.reminders
        return switch self {
        case .due(let days, let hidden): reminders.due(days: days, hiding: hidden, isRead: context.isRead)
        case .lists: reminders.lists(isRead: context.isRead)
        case .add(let words, let isDry): reminders.add(words, isDry: isDry, isRead: context.isRead)
        case .done(let id, let isDone): reminders.done(id, isDone, isRead: context.isRead)
        case .show(let id): reminders.show(id, isRead: context.isRead)
        }
    }
}
