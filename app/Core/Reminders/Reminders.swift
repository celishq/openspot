import Foundation

public struct Reminders {
    private static let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!
    private static let refusal = "Openspot has no access to your reminders. Allow Openspot in Privacy & Security › Reminders, then try again."

    private let store: any ReminderStore
    private let clock: CalendarClock
    private let isRead: Bool

    public init(store: any ReminderStore, now: Date = Date(), clock: Calendar = .current, locale: Locale = .current, isRead: Bool) {
        self.store = store
        self.clock = CalendarClock(now: now, calendar: clock, locale: locale)
        self.isRead = isRead
    }

    public func due(days: Int, hiding hidden: [String]) async throws -> String {
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        let end = clock.end(ofDay: days)
        let reminders = await store.reminders(dueBefore: end, doneSince: clock.startOfToday, hiding: hidden)
            .filter { reminder in reminder.due.map { $0 < end } ?? false }
            .sorted { first, second in
                if first.due != second.due { return (first.due ?? end) < (second.due ?? end) }
                return first.title < second.title
            }
        return Self.text(reminders.map { $0.row(clock) })
    }

    public func lists() async throws -> String {
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        return Self.text(store.lists().map(\.row))
    }

    public func done(_ id: String, _ isDone: Bool) async throws -> String {
        _ = try await isAllowed()
        guard case .reminder(let reminder)? = CalendarItemID(id), try store.mark(reminder: reminder, done: isDone) else { throw CalendarItemID.missing(id) }
        return ""
    }

    public func link(of id: String) async throws -> URL {
        _ = try await isAllowed()
        guard case .reminder(let key)? = CalendarItemID(id), let reminder = store.reminder(key),
              let link = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.id)") else { throw CalendarItemID.missing(id) }
        return link
    }

    public func add(_ words: String, isDry: Bool) async throws -> String {
        let entry = try CalendarEntry(titled: words)
        guard try await isAllowed() else { return CalendarAccess.unaskedText }
        guard let list = store.defaultList() else {
            throw SpotError.failed(1, "Openspot found no list for new reminders. Choose a default list in Reminders › Settings, then try again.")
        }
        let due = entry.date.map { entry.hasTime ? $0 : clock.calendar.startOfDay(for: $0) }
        let reminder = Reminder(id: "new", title: entry.title, due: due, isAllDay: due != nil && !entry.hasTime, list: list, doneAt: nil)
        guard !isDry else { return Self.text([TextBlock(fields: [.init(key: "row", value: "reminder:new")] + reminder.row(clock).fields.dropFirst())]) }
        return Self.text([try store.add(reminder).row(clock)])
    }

    private func isAllowed() async throws -> Bool {
        try await store.isAllowed(isRead: isRead, refusal: Self.refusal, pane: Self.pane)
    }

    private static func text(_ rows: [TextBlock]) -> String {
        rows.map { $0.text + "\n" }.joined()
    }
}
