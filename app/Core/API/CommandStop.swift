import Foundation

/// The stop of a call that may come before its task exists: a stop that comes first cancels the task as it arrives.
final class CommandStop: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<CommandAnswer, Never>?
    private var isStopped = false

    func hold(_ task: Task<CommandAnswer, Never>) {
        let stopped = lock.withLock {
            self.task = task
            return isStopped
        }
        if stopped { task.cancel() }
    }

    func cancel() {
        let task = lock.withLock {
            isStopped = true
            return self.task
        }
        task?.cancel()
    }
}
