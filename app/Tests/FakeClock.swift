import Foundation
import Synchronization
@testable import OpenspotCore

@MainActor
final class FakeClock {
    private struct Sleep {
        let id: Int
        let due: Date
        let wake: CheckedContinuation<Void, Error>
    }

    private struct Timer {
        let id: Int
        let due: Date
        let work: @Sendable () -> Void
    }

    private struct State {
        var time = Date(timeIntervalSince1970: 1000)
        var timers: [Timer] = []
        var made = 0
        var thread: TimeInterval = 0
    }

    private final class Shared: Sendable {
        let state = Mutex(State())

        func withLock<T>(_ body: (inout State) -> T) -> T {
            state.withLock { body(&$0) }
        }
    }

    private nonisolated let shared = Shared()
    private(set) var tolerances: [Duration?] = []
    private var sleeps: [Sleep] = []
    private var count = 0
    private let threadStep: TimeInterval?

    init(threadStep: TimeInterval? = nil) {
        self.threadStep = threadStep
    }

    private var threadTime: @Sendable () -> TimeInterval {
        guard let step = threadStep else { return ThreadTime.now }
        return { [shared] in
            shared.withLock { state in
                state.thread += step
                return state.thread
            }
        }
    }

    nonisolated var time: Date {
        shared.withLock { $0.time }
    }

    var value: RunClock {
        let threadTime = threadTime
        return RunClock(now: { [shared] in shared.withLock { $0.time } }, sleep: { duration, tolerance in
            self.tolerances.append(tolerance)
            try await self.sleep(duration)
        }, after: { [shared] seconds, work in
            let id = shared.withLock { shared in
                shared.made += 1
                shared.timers.append(Timer(id: shared.made, due: shared.time.addingTimeInterval(seconds), work: work))
                return shared.made
            }
        }, threadTime: threadTime)
    }

    var sleepCount: Int {
        sleeps.count
    }

    nonisolated var timerCount: Int {
        shared.withLock { $0.timers.count }
    }

    func isWaiting(for seconds: TimeInterval) -> Bool {
        let time = time
        let isTimed = shared.withLock { shared in shared.timers.contains { abs($0.due.timeIntervalSince(time) - seconds) < 0.001 } }
        return isTimed || sleeps.contains { abs($0.due.timeIntervalSince(time) - seconds) < 0.001 }
    }

    func advance(by seconds: TimeInterval) {
        let (time, timers) = shared.withLock { shared in
            shared.time = shared.time.addingTimeInterval(seconds)
            let due = shared.timers.filter { $0.due <= shared.time }.sorted { $0.due < $1.due }
            shared.timers.removeAll { $0.due <= shared.time }
            return (shared.time, due)
        }
        timers.forEach { $0.work() }
        let due = sleeps.filter { $0.due <= time }.sorted { $0.due < $1.due }
        sleeps.removeAll { $0.due <= time }
        due.forEach { $0.wake.resume() }
    }


    private func sleep(_ duration: Duration) async throws {
        count += 1
        let id = count
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        let due = time.addingTimeInterval(seconds)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (wake: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    wake.resume(throwing: CancellationError())
                } else {
                    sleeps.append(Sleep(id: id, due: due, wake: wake))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id) }
        }
    }


    private func cancel(_ id: Int) {
        guard let index = sleeps.firstIndex(where: { $0.id == id }) else { return }
        sleeps.remove(at: index).wake.resume(throwing: CancellationError())
    }
}
