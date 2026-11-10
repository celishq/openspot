import Foundation

/// Where the events and the reminders of the person live: EventKit in the app, and a fake in tests.
public protocol AgendaStore {
    func access(to kind: AgendaKind) -> AgendaAccess
    /// Asks macOS for leave, which shows its prompt the first time, and returns the answer.
    func ask(for kind: AgendaKind) async -> AgendaAccess
    /// Each event that overlaps the time from start to end, in the calendars with these ids, or in all with none.
    func events(from start: Date, to end: Date, in calendars: [String]) -> [AgendaEvent]
    /// Each open reminder due before the end, and each reminder done since the start, in the lists with these ids or in all.
    func reminders(dueBefore end: Date, doneSince start: Date, in lists: [String]) async -> [AgendaReminder]
    /// The reminder with this id, or nil when none has it.
    func reminder(_ id: String) -> AgendaReminder?
    /// Ticks the reminder with this id, or opens it again, and returns false when no reminder has the id.
    func mark(reminder id: String, done: Bool) throws -> Bool
    func lists(of kind: AgendaKind) -> [AgendaList]
    /// The calendar or the list that a new event or reminder goes to, or nil when the person has none.
    func defaultList(of kind: AgendaKind) -> AgendaList?
    /// Saves a new event in the default calendar, and returns it with its new id.
    func add(_ event: AgendaEvent) throws -> AgendaEvent
    /// Saves a new reminder in the default list, with an alert at its time when it has one, and returns it with its new id.
    func add(_ reminder: AgendaReminder) throws -> AgendaReminder
}
