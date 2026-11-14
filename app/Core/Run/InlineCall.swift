import Foundation

final class InlineCall: @unchecked Sendable {
    enum Outcome: @unchecked Sendable {
        case frame(String)
        case failed(Error)
        case dropped
    }

    let arguments: [String]
    let variables: [String: String]
    let input: String?
    let function: String?
    private let lock = NSLock()
    private let arrival = DispatchSemaphore(value: 0)
    private var outcome: Outcome?
    private var later: (@Sendable (Outcome) -> Void)?
    private var stopped = false
    private var isFinished = false

    init(arguments: [String], variables: [String: String] = [:], input: String? = nil, function: String? = nil) {
        self.arguments = arguments
        self.variables = variables
        self.input = input
        self.function = function
    }

    var isStopped: Bool {
        lock.withLock { stopped }
    }

    func stop() {
        lock.withLock { stopped = true }
    }

    func finish(_ outcome: Outcome) {
        lock.lock()
        guard !isFinished else { return lock.unlock() }
        isFinished = true
        if let later {
            self.later = nil
            lock.unlock()
            return later(outcome)
        }
        self.outcome = outcome
        lock.unlock()
        arrival.signal()
    }

    func wait(until deadline: DispatchTime, later: @escaping @Sendable (Outcome) -> Void) -> Outcome? {
        _ = arrival.wait(timeout: deadline)
        return lock.withLock {
            if let outcome { return outcome }
            self.later = later
            return nil
        }
    }

    func outcome(limit: TimeInterval? = nil) async -> Outcome {
        if let limit {
            DispatchQueue.global().asyncAfter(deadline: .now() + limit) { [self] in finish(.failed(SpotError.timedOut)) }
        }
        return await withCheckedContinuation { continuation in
            if let outcome = wait(until: .now(), later: { continuation.resume(returning: $0) }) { continuation.resume(returning: outcome) }
        }
    }
}
