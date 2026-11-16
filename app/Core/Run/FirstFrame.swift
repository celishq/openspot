import Foundation

@MainActor
final class FirstFrame {
    private var waiting: CheckedContinuation<CallAnswer, Error>?

    init(_ waiting: CheckedContinuation<CallAnswer, Error>) {
        self.waiting = waiting
    }

    @discardableResult
    func take(_ frame: SpotOutput) -> Bool {
        guard let waiting, !frame.isMark else { return false }
        self.waiting = nil
        if frame.fields.isEmpty {
            waiting.resume(returning: frame.isPicture || !frame.items.isEmpty ? .shown : .done)
        } else if let form = ItemForm(output: frame) {
            waiting.resume(returning: .form(form))
        } else {
            waiting.resume(throwing: SpotError.badForm)
        }
        return true
    }

    func end(_ answer: CallAnswer) {
        guard let waiting else { return }
        self.waiting = nil
        waiting.resume(returning: answer)
    }
}
