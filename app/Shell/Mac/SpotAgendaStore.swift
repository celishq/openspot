import EventKit
import OpenspotCore

/// The person's calendars and reminders, read and written through EventKit. An event that the person declined is left out.
final class SpotAgendaStore: AgendaStore {
    private let store = EKEventStore()

    /// The agenda of `openspot calendar` and `openspot reminders`, which knows a read by `OPENSPOT_REASON` (E7).
    static func agenda() -> Agenda {
        Agenda(store: SpotAgendaStore(), isRead: ProcessInfo.processInfo.environment["OPENSPOT_REASON"] != nil)
    }

    func access(to kind: AgendaKind) -> AgendaAccess {
        switch EKEventStore.authorizationStatus(for: Self.entity(of: kind)) {
        case .fullAccess: .allowed
        case .notDetermined: .unasked
        default: .denied
        }
    }

    func ask(for kind: AgendaKind) async -> AgendaAccess {
        let granted = switch kind {
        case .event: (try? await store.requestFullAccessToEvents()) ?? false
        case .reminder: (try? await store.requestFullAccessToReminders()) ?? false
        }
        return granted ? .allowed : .denied
    }

    func events(from start: Date, to end: Date, in calendars: [String]) -> [AgendaEvent] {
        let chosen = calendars.compactMap(store.calendar(withIdentifier:))
        guard calendars.isEmpty || !chosen.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars.isEmpty ? nil : chosen)
        return store.events(matching: predicate).filter { !Self.isDeclined($0) }.map { event in
            AgendaEvent(
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

    func lists(of kind: AgendaKind) -> [AgendaList] {
        store.calendars(for: Self.entity(of: kind)).map(Self.list)
    }

    private static func entity(of kind: AgendaKind) -> EKEntityType {
        kind == .event ? .event : .reminder
    }

    private static func list(_ calendar: EKCalendar?) -> AgendaList {
        let color = calendar?.cgColor.flatMap { $0.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil) }?.components
        return AgendaList(
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
