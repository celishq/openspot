import Foundation

public protocol ReminderStore: CalendarStore {
    func reminders(dueBefore end: Date, doneSince start: Date, hiding hidden: [String]) async -> [Reminder]
    func reminder(_ id: String) -> Reminder?
    func mark(reminder id: String, done: Bool) throws -> Bool
    func lists() -> [CalendarList]
    func defaultList() -> CalendarList?
    func add(_ reminder: Reminder) throws -> Reminder
}
