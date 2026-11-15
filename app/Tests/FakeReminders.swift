import Foundation
@testable import OpenspotCore

struct FakeReminders: MacReminders {
    var opened: @Sendable (URL) -> Bool = { _ in true }

    func store() -> any ReminderStore {
        FakeReminderStore()
    }

    func open(_ link: URL) -> Bool {
        opened(link)
    }
}
