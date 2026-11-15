import AppKit
import OpenspotCore

struct SpotRemindersApp: MacReminders {
    func store() -> any ReminderStore {
        SpotReminderStore()
    }

    func open(_ link: URL) -> Bool {
        NSWorkspace.shared.open(link)
    }
}
