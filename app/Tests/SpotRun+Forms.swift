import Foundation
@testable import OpenspotCore

@MainActor
extension SpotRun {
    func form(_ action: CommandAction, item: SpotItem?) async throws -> ItemForm? {
        switch await answer(to: action, item: item) {
        case .form(let form): form
        case .stopped: nil
        default: throw SpotError.badForm
        }
    }
}

@MainActor
extension SpotsModel {
    func openForm(_ action: CommandAction, on target: Target, prefill: String = "") {
        ask(action, on: target, prefill: prefill) { [sheets] in
            try await sheets[target.entry.id]?.form(action, item: target.item).map(CallAnswer.form)
        }
    }
}
