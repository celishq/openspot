import Foundation

@MainActor
final class FirstFrame {
    private var waiting: ((Result<CallAnswer, Error>) -> Void)?

    init(_ waiting: @escaping (Result<CallAnswer, Error>) -> Void) {
        self.waiting = waiting
    }

    @discardableResult
    func take(_ frame: Frame) -> Bool {
        guard let waiting, !frame.isMark else { return false }
        self.waiting = nil
        if !frame.isForm {
            waiting(.success(frame.isPicture || !frame.items.isEmpty ? .shown : .done))
        } else if let form = ItemForm(output: frame) {
            waiting(.success(.form(form)))
        } else {
            waiting(.failure(SpotError.badForm))
        }
        return true
    }

    func end(_ answer: CallAnswer) {
        guard let waiting else { return }
        self.waiting = nil
        waiting(.success(answer))
    }
}
