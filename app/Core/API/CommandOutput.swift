import Foundation

/// Where a call prints while it runs: each piece of stdout and of stderr, in order, before its answer ends it. One with no
/// place to print keeps what it gets, and puts it before the answer.
public final class CommandOutput: @unchecked Sendable {
    private let place: (@Sendable (_ text: String, _ isError: Bool) -> Void)?
    private let lock = NSLock()
    private var output = ""
    private var errors = ""

    public init(place: @escaping @Sendable (_ text: String, _ isError: Bool) -> Void) {
        self.place = place
    }

    init() {
        place = nil
    }

    public func print(_ text: String) {
        take(text, isError: false)
    }

    public func report(_ text: String) {
        take(text, isError: true)
    }

    /// The answer with what this kept before its own output and errors.
    func answer(ending answer: CommandAnswer) -> CommandAnswer {
        lock.withLock { CommandAnswer(output: output + answer.output, errors: errors + answer.errors, code: answer.code) }
    }

    private func take(_ text: String, isError: Bool) {
        guard !text.isEmpty else { return }
        guard let place else {
            return lock.withLock {
                if isError { errors += text } else { output += text }
            }
        }
        place(text, isError)
    }
}
