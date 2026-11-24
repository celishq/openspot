import Foundation

@MainActor
final class DueWatch {
    private let sleep: @MainActor (Duration, Duration?) async throws -> Void
    private let leeway: Duration?
    private var task: Task<Void, Never>?
    private(set) var due: Date?

    init(clock: RunClock, leeway: Duration? = nil) {
        sleep = clock.sleep
        self.leeway = leeway
    }

    var isWaiting: Bool {
        task != nil
    }

    func wait(until due: Date?, from now: Date, then work: @escaping @MainActor () -> Void) {
        stop()
        self.due = due
        guard let due else { return }
        let wait = Duration.seconds(max(0, due.timeIntervalSince(now)))
        let tolerance = leeway.map { min(wait / 10, $0) } ?? wait / 10
        task = Task { [weak self, sleep] in
            try? await sleep(wait, tolerance)
            guard !Task.isCancelled else { return }
            self?.task = nil
            self?.due = nil
            work()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        due = nil
    }
}
