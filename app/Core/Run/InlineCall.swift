import Foundation

/// One call of a JavaScript spot: its function and arguments, and the frame that its thread gives back. The main thread
/// waits a short time for the frame, and a frame that comes later goes to `later`. A stopped call that has not run never
/// runs.
final class InlineCall: @unchecked Sendable {
    /// How the call ended: the text of its frame, the error that it threw, or no run because it was stopped.
    enum Outcome: @unchecked Sendable {
        case frame(String)
        case failed(Error)
        case dropped
    }

    let arguments: [String]
    let reason: ReadReason?
    let input: String?
    private let lock = NSLock()
    private let arrival = DispatchSemaphore(value: 0)
    private var outcome: Outcome?
    private var later: (@Sendable (Outcome) -> Void)?
    private var stopped = false

    init(arguments: [String], reason: ReadReason? = nil, input: String? = nil) {
        self.arguments = arguments
        self.reason = reason
        self.input = input
    }

    var isStopped: Bool {
        lock.withLock { stopped }
    }

    func stop() {
        lock.withLock { stopped = true }
    }

    /// Gives the outcome to the waiting thread, or to `later` once that wait has ended.
    func finish(_ outcome: Outcome) {
        lock.lock()
        if let later {
            lock.unlock()
            return later(outcome)
        }
        self.outcome = outcome
        lock.unlock()
        arrival.signal()
    }

    /// Returns the outcome when it comes within the limit, or else nil, and the outcome goes to `later` when it comes.
    func wait(_ limit: DispatchTimeInterval, later: @escaping @Sendable (Outcome) -> Void) -> Outcome? {
        _ = arrival.wait(timeout: .now() + limit)
        return lock.withLock {
            if let outcome { return outcome }
            self.later = later
            return nil
        }
    }

    /// Waits for the outcome with no limit.
    func outcome() async -> Outcome {
        await withCheckedContinuation { continuation in
            if let outcome = wait(.seconds(0), later: { continuation.resume(returning: $0) }) { continuation.resume(returning: outcome) }
        }
    }
}
