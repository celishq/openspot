import EventKit
import OpenspotCore

@MainActor
final class SpotCalendarEvents {
    private let events = SpotEventStore()
    private let reminders = SpotReminderStore()
    private var observer: NSObjectProtocol?
    private var stamps: [String: CalendarStamp] = [:]
    private var wait: Task<Void, Never>?

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        stop()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed(heard) }
        }
        wait = Task { [weak self, events, reminders] in
            let first = await Self.stamps(events, reminders)
            self?.stamps = first
        }
    }

    private func changed(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        wait?.cancel()
        wait = Task { [weak self, events, reminders] in
            try? await Task.sleep(for: .seconds(1), tolerance: .seconds(1))
            guard !Task.isCancelled else { return }
            let next = await Self.stamps(events, reminders)
            guard let self, !Task.isCancelled else { return }
            for (name, stamp) in next.sorted(by: { $0.key < $1.key }) {
                if let event = stamp.event(name, after: stamps[name]) { heard(event) }
            }
            stamps = next
        }
    }

    private nonisolated static func stamps(_ events: SpotEventStore, _ reminders: SpotReminderStore) async -> [String: CalendarStamp] {
        await Task.detached {
            var stamps: [String: CalendarStamp] = [:]
            stamps[EventName.calendarChange] = events.stamp()
            stamps[EventName.remindersChange] = await reminders.stamp()
            return stamps
        }.value
    }

    private func stop() {
        wait?.cancel()
        wait = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
