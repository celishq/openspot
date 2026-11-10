import EventKit
import OpenspotCore

/// The person's reminders, read and written through EventKit.
final class SpotReminderStore: ReminderStore {
    private let store = EKEventStore()

    /// The reminders of `openspot reminders`, which know a read by `OPENSPOT_REASON` (E7).
    static func reminders() -> Reminders {
        Reminders(store: SpotReminderStore(), isRead: ProcessInfo.processInfo.environment["OPENSPOT_REASON"] != nil)
    }

    func access() -> CalendarAccess {
        SpotEventStore.access(to: .reminder)
    }

    func ask() async -> CalendarAccess {
        (try? await store.requestFullAccessToReminders()) == true ? .allowed : .denied
    }

    func reminders(dueBefore end: Date, doneSince start: Date, hiding hidden: [String]) async -> [Reminder] {
        let shown = store.calendars(for: .reminder).filter { !hidden.contains($0.calendarIdentifier) }
        guard !shown.isEmpty else { return [] }
        let open = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: shown)
        let done = store.predicateForCompletedReminders(withCompletionDateStarting: start, ending: nil, calendars: shown)
        return await fetch(open) + fetch(done)
    }

    func reminder(_ id: String) -> Reminder? {
        (store.calendarItem(withIdentifier: id) as? EKReminder).map(Self.reminder)
    }

    func mark(reminder id: String, done: Bool) throws -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        reminder.isCompleted = done
        try store.save(reminder, commit: true)
        return true
    }

    func lists() -> [CalendarList] {
        store.calendars(for: .reminder).map(SpotEventStore.list)
    }

    func defaultList() -> CalendarList? {
        store.defaultCalendarForNewReminders().map(SpotEventStore.list)
    }

    func add(_ reminder: Reminder) throws -> Reminder {
        let new = EKReminder(eventStore: store)
        new.title = reminder.title
        new.calendar = store.defaultCalendarForNewReminders()
        if let due = reminder.due {
            let parts: Set<Calendar.Component> = reminder.isAllDay ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute]
            new.dueDateComponents = Calendar.current.dateComponents(parts, from: due)
            if !reminder.isAllDay { new.addAlarm(EKAlarm(absoluteDate: due)) }
        }
        try store.save(new, commit: true)
        return Reminder(id: new.calendarItemIdentifier, title: reminder.title, due: reminder.due, isAllDay: reminder.isAllDay, list: SpotEventStore.list(new.calendar), doneAt: nil)
    }

    /// The reminders that a predicate matches, read into values in the callback, where EventKit hands them over.
    private func fetch(_ predicate: NSPredicate) async -> [Reminder] {
        await withCheckedContinuation { answer in
            store.fetchReminders(matching: predicate) { reminders in
                answer.resume(returning: (reminders ?? []).map(Self.reminder))
            }
        }
    }

    private static func reminder(_ reminder: EKReminder) -> Reminder {
        let parts = reminder.dueDateComponents
        return Reminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            due: parts.flatMap { Calendar.current.date(from: $0) },
            isAllDay: parts != nil && parts?.hour == nil,
            list: SpotEventStore.list(reminder.calendar),
            doneAt: reminder.isCompleted ? reminder.completionDate ?? Date() : nil
        )
    }
}
