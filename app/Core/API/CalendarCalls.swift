import Foundation

final class CalendarCalls: @unchecked Sendable {
    private let mac: any Mac
    private let lock = NSLock()
    private var store: (any EventStore)?

    init(mac: any Mac) {
        self.mac = mac
    }

    func events(days: Int, hiding hidden: [String], isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isRead).events(days: days, hiding: hidden) }
    }

    func calendars(isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isRead).calendars() }
    }

    func add(_ words: String, isDry: Bool, isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isRead).add(words, isDry: isDry) }
    }

    func show(_ id: String, isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work {
            try self.mac.showCalendar(at: try await self.events(isRead).day(of: id))
            return ""
        }
    }

    private func events(_ isRead: Bool) -> Events {
        let store = lock.withLock {
            let store = self.store ?? mac.eventStore()
            self.store = store.access() == .allowed ? store : nil
            return store
        }
        return Events(store: store, isRead: isRead)
    }
}
