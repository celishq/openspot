import EventKit
import OpenspotCore

@MainActor
final class SpotCalendarEvents {
    private let events = SpotEventStore()
    private let reminders = SpotReminderStore()
    private var observer: NSObjectProtocol?
    private var samples: [String: CalendarSample] = [:]
    private var wait: Task<Void, Never>?

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        stop()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed(heard) }
        }
        wait = Task { [weak self, events, reminders] in
            let first = await Self.samples(events, reminders)
            self?.samples = first
        }
    }

    private func changed(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        wait?.cancel()
        wait = Task { [weak self, events, reminders] in
            try? await Task.sleep(for: .seconds(1), tolerance: .seconds(1))
            guard !Task.isCancelled else { return }
            let next = await Self.samples(events, reminders)
            guard let self, !Task.isCancelled else { return }
            for (name, sample) in next.sorted(by: { $0.key < $1.key }) {
                if let event = sample.event(name, after: samples[name]) { heard(event) }
            }
            samples = next
        }
    }

    private nonisolated static func samples(_ events: SpotEventStore, _ reminders: SpotReminderStore) async -> [String: CalendarSample] {
        await Task.detached {
            var samples: [String: CalendarSample] = [:]
            samples[EventName.calendarChange] = events.sample()
            samples[EventName.remindersChange] = await reminders.sample()
            return samples
        }.value
    }

    private func stop() {
        wait?.cancel()
        wait = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
