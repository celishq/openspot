import Foundation

final class RemindersCalls: @unchecked Sendable {
    private let mac: (any MacReminders)?
    private let lock = NSLock()
    private var store: (any ReminderStore)?

    init(mac: (any MacReminders)?) {
        self.mac = mac
    }

    func due(days: Int, hiding hidden: [String], isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.reminders(isRead).due(days: days, hiding: hidden) }
    }

    func lists(isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.reminders(isRead).lists() }
    }

    func add(_ words: String, isDry: Bool, isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.reminders(isRead).add(words, isDry: isDry) }
    }

    func done(_ id: String, _ isDone: Bool, isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work { try await self.reminders(isRead).done(id, isDone) }
    }

    func show(_ id: String, isRead: Bool) -> CommandAPI.Work {
        CommandAnswer.work {
            let link = try await self.reminders(isRead).link(of: id)
            guard try Mac.part(self.mac, "reminders").open(link) else { throw SpotError.failed(1, "Openspot cannot open Reminders, so it cannot show \(id).") }
            return ""
        }
    }

    private func reminders(_ isRead: Bool) throws -> Reminders {
        let mac = try Mac.part(mac, "reminders")
        let store = lock.withLock {
            let store = self.store ?? mac.store()
            self.store = store.access() == .allowed ? store : nil
            return store
        }
        return Reminders(store: store, isRead: isRead)
    }
}
