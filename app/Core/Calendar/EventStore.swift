import Foundation

/// Where the events of the person live: EventKit in the app, and a fake in tests.
public protocol EventStore: CalendarStore {
    /// Each event that overlaps the time from start to end, in each calendar whose id is not hidden.
    func events(from start: Date, to end: Date, hiding hidden: [String]) -> [Event]
    func calendars() -> [CalendarList]
    /// The calendar that a new event goes to, or nil when the person has none.
    func defaultCalendar() -> CalendarList?
    /// Saves a new event in the default calendar, and returns it with its new id.
    func add(_ event: Event) throws -> Event
}
