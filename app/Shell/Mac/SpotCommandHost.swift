import AppKit
import OpenspotCore

/// What the API reaches through the Mac: EventKit, Calendar, and the app that opens a link.
struct SpotCommandHost: CommandHost {
    func eventStore() -> any EventStore {
        SpotEventStore()
    }

    func reminderStore() -> any ReminderStore {
        SpotReminderStore()
    }

    func showCalendar(at time: Date) throws {
        _ = try SpotCalendarApp.show(time)
    }

    func open(_ link: URL) -> Bool {
        NSWorkspace.shared.open(link)
    }
}
