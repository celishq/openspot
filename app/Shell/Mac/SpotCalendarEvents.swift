import EventKit
import OpenspotCore

@MainActor
final class SpotCalendarEvents {
    private let read = SpotCalendarRead()
    private var observer: NSObjectProtocol?
    private var stamps: [String: CalendarStamp] = [:]
    private var wait: Task<Void, Never>?

    func listen(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        stop()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: read.store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed(heard) }
        }
        let read = read
        wait = Task { [weak self] in
            let first = await Task.detached { await read.stamps() }.value
            self?.stamps = first
        }
    }

    private func changed(_ heard: @escaping @MainActor (AppSignal) -> Void) {
        wait?.cancel()
        let read = read
        wait = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1), tolerance: .seconds(1))
            guard !Task.isCancelled else { return }
            let next = await Task.detached { await read.stamps() }.value
            guard let self, !Task.isCancelled else { return }
            for (name, stamp) in next.sorted(by: { $0.key < $1.key }) {
                if let event = stamp.event(name, after: stamps[name]) { heard(event) }
            }
            stamps = next
        }
    }

    private func stop() {
        wait?.cancel()
        wait = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
