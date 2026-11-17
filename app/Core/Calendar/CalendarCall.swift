import Foundation

enum CalendarCall: NounCall {
    case events(days: Int, hidden: [String])
    case calendars
    case add(words: String, isDry: Bool)
    case show(id: String)

    private static let read = "read your calendar"

    static let noun = CommandNoun("calendar", group: .mac, guide: "calendar", verbs: [
        CommandVerb("events", "[--days n] [--hide id]...", "Prints each event that has not ended through the end of day n as a row. Day 1, the default, is today. --hide leaves out a calendar.", rule: CallRule(use: .calendar, used: read)) { words in
            words.fit.flatMap { fit in fit.rest.isEmpty ? fit.days.map { Self.events(days: $0, hidden: fit.values("--hide")) } : nil }
        },
        CommandVerb("calendars", "", "Prints each calendar as a row.", rule: CallRule(use: .calendar, used: read)) { $0.none ? Self.calendars : nil },
        CommandVerb("add", "[--dry-run] <words>...", "Adds an event from words such as Lunch tomorrow 13:00, and prints its row. --dry-run prints the row and adds nothing.", rule: CallRule(use: .calendar, used: "added an event", read: .changes("changes your calendars"))) { words in
            words.fit.flatMap { $0.rest.isEmpty ? nil : Self.add(words: $0.rest.joined(separator: " "), isDry: $0.has("--dry-run")) }
        },
        CommandVerb("show", "<id>", "Opens Calendar on the day of the event of a row.", rule: CallRule(use: .calendar, used: "opened Calendar", read: .changes("opens Calendar"))) { $0.one.map { Self.show(id: $0) } }
    ])

    func rule(_ rule: CallRule, spot: String?) -> CallRule {
        guard case .add(_, true) = self else { return rule }
        var rule = rule
        rule.read = .free
        return rule
    }

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calendar = context.calendar
        return switch self {
        case .events(let days, let hidden): calendar.events(days: days, hiding: hidden, isRead: context.isRead)
        case .calendars: calendar.calendars(isRead: context.isRead)
        case .add(let words, let isDry): calendar.add(words, isDry: isDry, isRead: context.isRead)
        case .show(let id): calendar.show(id, isRead: context.isRead)
        }
    }
}
