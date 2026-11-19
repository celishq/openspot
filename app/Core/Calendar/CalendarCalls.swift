import Foundation

final class CalendarCalls: @unchecked Sendable {
    private let mac: (any MacCalendar)?
    private let lock = NSLock()
    private var store: (any EventStore)?

    init(mac: (any MacCalendar)?) {
        self.mac = mac
    }

    func events(days: Int, hiding hidden: [String], isInShow: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isInShow).events(days: days, hiding: hidden) }
    }

    func calendars(isInShow: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isInShow).calendars() }
    }

    func add(_ words: String, isDry: Bool, isInShow: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.events(isInShow).add(words, isDry: isDry) }
    }

    func show(_ id: String, isInShow: Bool) -> CommandAPI.Work {
        CommandAnswer.work {
            try Mac.part(self.mac, "calendar").show(try await self.events(isInShow).day(of: id))
            return ""
        }
    }

    private func events(_ isInShow: Bool) throws -> Events {
        let mac = try Mac.part(mac, "calendar")
        let store = lock.withLock {
            let store = self.store ?? mac.store()
            self.store = store.access() == .allowed ? store : nil
            return store
        }
        return Events(store: store, isInShow: isInShow)
    }
}
