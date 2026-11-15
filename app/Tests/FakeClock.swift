import Foundation
@testable import OpenspotCore

@MainActor
final class FakeClock {
    private struct Sleep {
        let id: Int
        let due: Date
        let wake: CheckedContinuation<Void, Error>
    }

    private(set) var time = Date(timeIntervalSince1970: 1000)
    private var sleeps: [Sleep] = []
    private var count = 0
    private let isReal: Bool

    init(isReal: Bool = false) {
        self.isReal = isReal
    }

    var value: RunClock {
        RunClock(now: { self.time }, sleep: { duration, _ in try await self.sleep(duration) })
    }

    var sleepCount: Int {
        sleeps.count
    }

    func isSleeping(for seconds: TimeInterval) -> Bool {
        sleeps.contains { abs($0.due.timeIntervalSince(time) - seconds) < 0.001 }
    }

    func advance(by seconds: TimeInterval) {
        time = time.addingTimeInterval(seconds)
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
                    if isReal { wakeLater(id, after: duration) }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(id) }
        }
    }

    private func wakeLater(_ id: Int, after duration: Duration) {
        Task { [weak self] in
            try? await RunClock().sleep(duration, nil)
            guard let self, let index = sleeps.firstIndex(where: { $0.id == id }) else { return }
            sleeps.remove(at: index).wake.resume()
        }
    }

    private func cancel(_ id: Int) {
        guard let index = sleeps.firstIndex(where: { $0.id == id }) else { return }
        sleeps.remove(at: index).wake.resume(throwing: CancellationError())
    }
}
