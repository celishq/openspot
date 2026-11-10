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

    func reminders(dueBefore end: Date, doneSince start: Date, in lists: [String]) async -> [AgendaReminder] {
        let chosen = lists.compactMap(store.calendar(withIdentifier:))
        guard lists.isEmpty || !chosen.isEmpty else { return [] }
        let calendars = lists.isEmpty ? nil : chosen
        let open = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: calendars)
        let done = store.predicateForCompletedReminders(withCompletionDateStarting: start, ending: nil, calendars: calendars)
        return await fetch(open) + fetch(done)
    }

    func reminder(_ id: String) -> AgendaReminder? {
        (store.calendarItem(withIdentifier: id) as? EKReminder).map(Self.reminder)
    }

    func mark(reminder id: String, done: Bool) throws -> Bool {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return false }
        reminder.isCompleted = done
        try store.save(reminder, commit: true)
        return true
    }

    func lists(of kind: AgendaKind) -> [AgendaList] {
        store.calendars(for: Self.entity(of: kind)).map(Self.list)
    }

    func defaultList(of kind: AgendaKind) -> AgendaList? {
        (kind == .event ? store.defaultCalendarForNewEvents : store.defaultCalendarForNewReminders()).map(Self.list)
    }

    func add(_ event: AgendaEvent) throws -> AgendaEvent {
        let new = EKEvent(eventStore: store)
        new.title = event.title
        new.startDate = event.start
        new.endDate = event.end
        new.isAllDay = event.isAllDay
        new.calendar = store.defaultCalendarForNewEvents
        try store.save(new, span: .thisEvent, commit: true)
        return AgendaEvent(
            id: new.eventIdentifier ?? new.calendarItemIdentifier, title: event.title, start: event.start, end: event.end, isAllDay: event.isAllDay,
            calendar: Self.list(new.calendar), location: nil, url: nil, notes: nil
        )
    }

    func add(_ reminder: AgendaReminder) throws -> AgendaReminder {
        let new = EKReminder(eventStore: store)
        new.title = reminder.title
        new.calendar = store.defaultCalendarForNewReminders()
        if let due = reminder.due {
            let parts: Set<Calendar.Component> = reminder.isAllDay ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute]
            new.dueDateComponents = Calendar.current.dateComponents(parts, from: due)
            if !reminder.isAllDay { new.addAlarm(EKAlarm(absoluteDate: due)) }
        }
        try store.save(new, commit: true)
        return AgendaReminder(id: new.calendarItemIdentifier, title: reminder.title, due: reminder.due, isAllDay: reminder.isAllDay, list: Self.list(new.calendar), doneAt: nil)
    }

    /// The reminders that a predicate matches, read into values in the callback, where EventKit hands them over.
    private func fetch(_ predicate: NSPredicate) async -> [AgendaReminder] {
        await withCheckedContinuation { answer in
            store.fetchReminders(matching: predicate) { reminders in
                answer.resume(returning: (reminders ?? []).map(Self.reminder))
            }
        }
    }

    private static func reminder(_ reminder: EKReminder) -> AgendaReminder {
        let parts = reminder.dueDateComponents
        return AgendaReminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            due: parts.flatMap { Calendar.current.date(from: $0) },
            isAllDay: parts != nil && parts?.hour == nil,
            list: list(reminder.calendar),
            doneAt: reminder.isCompleted ? reminder.completionDate ?? Date() : nil
        )
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
