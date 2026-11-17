import Foundation

final class PowerReply<Answer: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Answer, Error>?

    init(_ continuation: CheckedContinuation<Answer, Error>) {
        self.continuation = continuation
    }

    func give(_ result: Result<Answer, Error>) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}
