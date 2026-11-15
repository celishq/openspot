import Foundation
@testable import OpenspotCore

final class FakeEventStore: EventStore {
    struct Range: Equatable {
        let start: Date
        let end: Date
        let hidden: [String]
    }

    private let allEvents: [Event]
    private let allCalendars: [CalendarList]
    private let calendar: CalendarList?
    private var state: CalendarAccess
    private let answer: CalendarAccess
    private(set) var asks = 0
    private(set) var ranges: [Range] = []
    private(set) var added: [Event] = []

    init(events: [Event] = [], calendars: [CalendarList] = [], defaultCalendar: CalendarList? = nil, access: CalendarAccess = .allowed, answer: CalendarAccess = .allowed) {
        allEvents = events
        allCalendars = calendars
        calendar = defaultCalendar
        state = access
        self.answer = answer
    }

    func access() -> CalendarAccess {
        state
    }

    func ask() async -> CalendarAccess {
        asks += 1
        state = answer
        return answer
    }

    func events(from start: Date, to end: Date, hiding hidden: [String]) -> [Event] {
        ranges.append(Range(start: start, end: end, hidden: hidden))
        return allEvents.filter { $0.start < end && $0.end > start }
    }

    func calendars() -> [CalendarList] {
        allCalendars
    }

    func defaultCalendar() -> CalendarList? {
        calendar
    }

    func add(_ event: Event) throws -> Event {
        added.append(event)
        return Event(id: "saved-\(added.count)", title: event.title, start: event.start, end: event.end, isAllDay: event.isAllDay, calendar: calendar!, location: nil, url: nil, notes: nil)
    }
}
