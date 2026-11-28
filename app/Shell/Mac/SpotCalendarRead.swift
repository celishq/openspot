import EventKit
import OpenspotCore

final class SpotCalendarRead: @unchecked Sendable {
    let store = EKEventStore()

    func stamps() async -> [String: CalendarStamp] {
        var stamps: [String: CalendarStamp] = [:]
        if SpotEventStore.access(to: .event) == .allowed {
            let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86_400)
            let predicate = store.predicateForEvents(withStart: start, end: start.addingTimeInterval(366 * 86_400), calendars: nil)
            stamps[EventName.calendarChange] = CalendarStamp(edits: store.events(matching: predicate).map(\.lastModifiedDate))
        }
        if SpotEventStore.access(to: .reminder) == .allowed {
            let predicate = store.predicateForReminders(in: nil)
            let edits = await withCheckedContinuation { answer in
                store.fetchReminders(matching: predicate) { reminders in
                    answer.resume(returning: (reminders ?? []).map(\.lastModifiedDate))
                }
            }
            stamps[EventName.remindersChange] = CalendarStamp(edits: edits)
        }
        return stamps
    }
}
