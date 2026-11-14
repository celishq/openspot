import EventKit
import OpenspotCore

final class SpotEventStore: EventStore {
    private let store = EKEventStore()


    func access() -> CalendarAccess {
        Self.access(to: .event)
    }

    func ask() async -> CalendarAccess {
        (try? await store.requestFullAccessToEvents()) == true ? .allowed : .denied
    }

    func events(from start: Date, to end: Date, hiding hidden: [String]) -> [Event] {
        let shown = store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        guard !shown.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: shown)
        return store.events(matching: predicate).filter { !Self.isDeclined($0) }.map { event in
            Event(
                id: event.eventIdentifier ?? event.calendarItemIdentifier,
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendar: Self.list(event.calendar),
                location: event.location,
                url: event.url?.absoluteString,
                notes: event.notes
            )
        }
    }

    func calendars() -> [CalendarList] {
        store.calendars(for: .event).map(Self.list)
    }

    func defaultCalendar() -> CalendarList? {
        store.defaultCalendarForNewEvents.map(Self.list)
    }

    func add(_ event: Event) throws -> Event {
        let new = EKEvent(eventStore: store)
        new.title = event.title
        new.startDate = event.start
        new.endDate = event.end
        new.isAllDay = event.isAllDay
        new.calendar = store.defaultCalendarForNewEvents
        try store.save(new, span: .thisEvent, commit: true)
        return Event(
            id: new.eventIdentifier ?? new.calendarItemIdentifier, title: event.title, start: event.start, end: event.end, isAllDay: event.isAllDay,
            calendar: Self.list(new.calendar), location: nil, url: nil, notes: nil
        )
    }

    static func access(to entity: EKEntityType) -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: entity) {
        case .fullAccess: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    static func list(_ calendar: EKCalendar?) -> CalendarList {
        let color = calendar?.cgColor.flatMap { $0.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) }?.components
        return CalendarList(
            id: calendar?.calendarIdentifier ?? "",
            title: calendar?.title ?? "",
            account: calendar?.source?.title ?? "",
            color: color.flatMap { $0.count >= 3 ? HexColor(red: $0[0], green: $0[1], blue: $0[2]).text : nil }
        )
    }

    private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.first(where: \.isCurrentUser)?.participantStatus == .declined
    }
}
