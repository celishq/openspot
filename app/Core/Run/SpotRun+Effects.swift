import Foundation

extension SpotRun {
    func isOutOfDate(_ call: OpenCall) -> Bool {
        guard !call.made.isStopped else { return true }
        guard case .act(let act) = call.request.purpose, let generation = act.generation else { return false }
        return partsGeneration != generation
    }

    var partsGeneration: Int? {
        panel?.holdsParts == true ? panel?.generation : nil
    }

    func take(_ effect: SpotEffect, of call: OpenCall?) {
        switch effect {
        case .toast(let note):
            onReport(.toast(note.hiding(fieldValues)))
        case .dropToast(let id):
            onReport(.dropToast(id))
        case .select(let item):
            selecting = item
            call?.selected = item
        case .route(let move):
            onReport(.move(move))
        case .attachment(let value):
            onReport(.attachment(value))
        }
    }
}
