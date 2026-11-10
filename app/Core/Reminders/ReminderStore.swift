import Foundation

/// Where the reminders of the person live: EventKit in the app, and a fake in tests.
public protocol ReminderStore: CalendarStore {
    /// Each open reminder due before the end, and each reminder done since the start, in each list whose id is not hidden.
    func reminders(dueBefore end: Date, doneSince start: Date, hiding hidden: [String]) async -> [Reminder]
    /// The reminder with this id, or nil when none has it.
    func reminder(_ id: String) -> Reminder?
    /// Ticks the reminder with this id, or opens it again, and returns false when no reminder has the id.
    func mark(reminder id: String, done: Bool) throws -> Bool
    func lists() -> [CalendarList]
    /// The list that a new reminder goes to, or nil when the person has none.
    func defaultList() -> CalendarList?
    /// Saves a new reminder in the default list, with an alert at its time when it has one, and returns it with its new id.
    func add(_ reminder: Reminder) throws -> Reminder
}
