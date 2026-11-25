import Foundation

final class FirstAnswer<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var given: Value?
    private var isGiven = false

    func give(_ value: Value) -> Bool {
        lock.withLock {
            guard !isGiven else { return false }
            isGiven = true
            given = value
            return true
        }
    }

    var value: Value? {
        lock.withLock { given }
    }
}
