import Foundation

final class CallLimit: @unchecked Sendable {
    private let lock = NSLock()
    private let clock: RunClock
    private let over: @Sendable () -> Void
    private var left: TimeInterval
    private var deadline: Date?
    private var isStarted = false
    private var isEnded = false
    private var holds = 0
    private var turn = 0

    init(seconds: TimeInterval, clock: RunClock, over: @escaping @Sendable () -> Void) {
        left = seconds
        self.clock = clock
        self.over = over
    }

    var due: Date? {
        lock.withLock { deadline }
    }

    var isRunning: Bool {
        lock.withLock { deadline != nil }
    }

    func start() {
        lock.withLock { isStarted = true }
        arm()
    }

    func hold() {
        lock.withLock {
            holds += 1
            guard holds == 1, let deadline else { return }
            left = max(0, deadline.timeIntervalSince(clock.now()))
            self.deadline = nil
            turn += 1
        }
    }

    func release() {
        lock.withLock { holds = max(0, holds - 1) }
        arm()
    }

    func end() {
        lock.withLock {
            isEnded = true
            deadline = nil
            turn += 1
        }
    }

    private func arm() {
        let armed = lock.withLock { () -> (turn: Int, seconds: TimeInterval)? in
            guard isStarted, holds == 0, !isEnded, deadline == nil else { return nil }
            deadline = clock.now().addingTimeInterval(left)
            turn += 1
            return (turn, left)
        }
        guard let armed else { return }
        clock.after(armed.seconds) { [self] in
            let isOver = lock.withLock {
                guard turn == armed.turn, !isEnded else { return false }
                isEnded = true
                deadline = nil
                return true
            }
            if isOver { over() }
        }
    }
}
