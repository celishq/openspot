import Foundation

extension SpotRun {
    func isOutOfDate(_ call: OpenCall) -> Bool {
        guard !call.made.isStopped else { return true }
        guard case .work(let work) = call.request.purpose, let generation = work.generation else { return false }
        return panel?.generation != generation
    }

    func take(_ effect: SpotEffect, of call: OpenCall?) {
        switch effect {
        case .toast(let text):
            onReport(.toast(fieldValues.hiding(text)))
        case .select(let item):
            selecting = item
            call?.selected = item
        case .route(let move):
            onReport(.move(move))
        }
    }
}
