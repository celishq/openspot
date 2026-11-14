import Foundation

public protocol EventStore: CalendarStore {
    func events(from start: Date, to end: Date, hiding hidden: [String]) -> [Event]
    func calendars() -> [CalendarList]
    func defaultCalendar() -> CalendarList?
    func add(_ event: Event) throws -> Event
}
