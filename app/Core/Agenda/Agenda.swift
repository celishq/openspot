import Foundation

/// The events and the reminders of the person as the rows that `openspot calendar` and `openspot reminders` print (E1).
/// A read never asks for leave: it says `status=unasked`, and a call outside a read asks (E6, E7).
public struct Agenda {
    static let unasked = "status=unasked\n"

    private let store: any AgendaStore
    private let clock: AgendaClock
    private let isRead: Bool

    public init(store: any AgendaStore, now: Date = Date(), clock: Calendar = .current, locale: Locale = .current, isRead: Bool) {
        self.store = store
        self.clock = AgendaClock(now: now, calendar: clock, locale: locale)
        self.isRead = isRead
    }

    /// Each event that has not ended, through the end of a day, in the order of its start.
    public func events(days: Int, calendars: [String]) async throws -> String {
        guard try await isAllowed(.event) else { return Self.unasked }
        let events = store.events(from: clock.now, to: clock.end(ofDay: days), in: calendars)
            .filter { $0.end > clock.now }
            .sorted { first, second in
                if first.start != second.start { return first.start < second.start }
                if first.isAllDay != second.isAllDay { return first.isAllDay }
                return first.title < second.title
            }
        return Self.text(events.map { $0.row(clock) })
    }

    public func calendars() async throws -> String {
        guard try await isAllowed(.event) else { return Self.unasked }
        return Self.text(store.lists(of: .event).map(\.row))
    }

    /// Each open reminder that is late or due through the end of a day, and each one of those days done today, in the order
    /// of its due time, so that a reminder keeps its place when it is ticked (E3).
    public func due(days: Int, lists: [String]) async throws -> String {
        guard try await isAllowed(.reminder) else { return Self.unasked }
        let end = clock.end(ofDay: days)
        let reminders = await store.reminders(dueBefore: end, doneSince: clock.startOfToday, in: lists)
            .filter { reminder in reminder.due.map { $0 < end } ?? false }
            .sorted { first, second in
                if first.due != second.due { return (first.due ?? end) < (second.due ?? end) }
                return first.title < second.title
            }
        return Self.text(reminders.map { $0.row(clock) })
    }

    public func lists() async throws -> String {
        guard try await isAllowed(.reminder) else { return Self.unasked }
        return Self.text(store.lists(of: .reminder).map(\.row))
    }

    /// Ticks the reminder with the id of its row, or opens it again, and prints nothing.
    public func done(_ id: String, _ isDone: Bool) async throws -> String {
        _ = try await isAllowed(.reminder)
        guard case .reminder(let reminder)? = AgendaID(id), try store.mark(reminder: reminder, done: isDone) else { throw Self.missing(id) }
        return ""
    }

    /// The link that opens Reminders on the reminder whose row has this id.
    public func link(of id: String) async throws -> URL {
        _ = try await isAllowed(.reminder)
        guard case .reminder(let key)? = AgendaID(id), let reminder = store.reminder(key),
              let link = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.id)") else { throw Self.missing(id) }
        return link
    }

    /// The time of the event whose row has this id, on whose day Calendar opens.
    public func day(of id: String) async throws -> Date {
        switch AgendaID(id) {
        case .event(_, let start)?: return start
        case .reminder?: throw PluginError.failed(1, "\(id) is a reminder. Run `openspot reminders show \(id)` to open it in Reminders.")
        case nil: throw Self.missing(id)
        }
    }

    /// Adds an event from the words, and prints its row. A dry run prints the row it would add, with the id `event:new` (E5).
    public func addEvent(_ words: String, isDry: Bool) async throws -> String {
        let entry = try Self.entry(words)
        guard let date = entry.date else {
            throw PluginError.failed(1, "Openspot found no date in `\(Self.trimmed(words))`. Add one, such as `tomorrow 9am`.")
        }
        guard try await isAllowed(.event) else { return Self.unasked }
        guard let calendar = store.defaultList(of: .event) else {
            throw PluginError.failed(1, "Openspot found no calendar for new events. Choose a default calendar in Calendar › Settings › General, then try again.")
        }
        let start = entry.hasTime ? date : clock.calendar.startOfDay(for: date)
        let end = entry.hasTime ? start.addingTimeInterval(entry.length ?? 3600) : clock.calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let event = AgendaEvent(id: "new", title: entry.title, start: start, end: end, isAllDay: !entry.hasTime, calendar: calendar, location: nil, url: nil, notes: nil)
        guard !isDry else { return Self.text([Self.new(event.row(clock), "event:new")]) }
        return Self.text([try store.add(event).row(clock)])
    }

    /// Adds a reminder from the words, due at their date when they have one, and prints its row. A dry run prints the row it
    /// would add, with the id `reminder:new` (E5).
    public func addReminder(_ words: String, isDry: Bool) async throws -> String {
        let entry = try Self.entry(words)
        guard try await isAllowed(.reminder) else { return Self.unasked }
        guard let list = store.defaultList(of: .reminder) else {
            throw PluginError.failed(1, "Openspot found no list for new reminders. Choose a default list in Reminders › Settings, then try again.")
        }
        let due = entry.date.map { entry.hasTime ? $0 : clock.calendar.startOfDay(for: $0) }
        let reminder = AgendaReminder(id: "new", title: entry.title, due: due, isAllDay: due != nil && !entry.hasTime, list: list, doneAt: nil)
        guard !isDry else { return Self.text([Self.new(reminder.row(clock), "reminder:new")]) }
        return Self.text([try store.add(reminder).row(clock)])
    }

    /// The title and the date in the words, or a failure that says what the words lack.
    private static func entry(_ words: String) throws -> AgendaEntry {
        guard !trimmed(words).isEmpty else { throw PluginError.failed(1, "Openspot needs words, such as `Lunch tomorrow 13:00`.") }
        let entry = AgendaEntry(words: words)
        guard !entry.title.isEmpty else {
            throw PluginError.failed(1, "Openspot found only a date in `\(trimmed(words))`. Add a title, such as `Lunch tomorrow 13:00`.")
        }
        return entry
    }

    private static func missing(_ id: String) -> PluginError {
        PluginError.failed(1, "Openspot cannot find \(id). Read the list again, and use the id of one of its rows.")
    }

    private static func trimmed(_ words: String) -> String {
        words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A row with the id of an item that is not saved yet.
    private static func new(_ row: TextBlock, _ id: String) -> TextBlock {
        TextBlock(fields: [.init(key: "row", value: id)] + row.fields.dropFirst())
    }

    /// Whether the store may be read. A read that has not asked returns false, a call outside a read asks first, and a
    /// refusal fails with the pane that fixes it (E8).
    private func isAllowed(_ kind: AgendaKind) async throws -> Bool {
        var access = store.access(to: kind)
        if access == .unasked {
            guard !isRead else { return false }
            access = await store.ask(for: kind)
        }
        guard access == .allowed else { throw PluginError.failedWithFix(1, kind.refusal, kind.pane) }
        return true
    }

    private static func text(_ rows: [TextBlock]) -> String {
        rows.map { $0.text + "\n" }.joined()
    }
}
