import Foundation
import Synchronization
@testable import OpenspotCore

final class FakeMac: Mac {
    let login: LoginItem?
    private let opens: Bool
    private let kept = Mutex<[String]>([])

    init(opens: Bool = true, login: LoginItem? = nil) {
        self.opens = opens
        self.login = login
    }

    var calls: [String] {
        kept.withLock { $0 }
    }

    func eventStore() -> any EventStore {
        keep("eventStore")
        return FakeEventStore()
    }

    func reminderStore() -> any ReminderStore {
        keep("reminderStore")
        return FakeReminderStore()
    }

    func showCalendar(at time: Date) throws {
        keep("showCalendar")
    }

    func open(_ link: URL) -> Bool {
        keep("open \(link.absoluteString)")
        return opens
    }

    private func keep(_ call: String) {
        kept.withLock { $0.append(call) }
    }
}
