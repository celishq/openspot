import Foundation

@MainActor
final class FirstFrame {
    private var waiting: CheckedContinuation<FirstAnswer, Never>?

    init(_ waiting: CheckedContinuation<FirstAnswer, Never>) {
        self.waiting = waiting
    }

    @discardableResult
    func take(_ answer: FirstAnswer) -> Bool {
        guard let waiting else { return false }
        self.waiting = nil
        waiting.resume(returning: answer)
        return true
    }
}
