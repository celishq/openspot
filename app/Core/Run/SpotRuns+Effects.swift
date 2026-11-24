import Foundation

extension SpotRuns {
    func take(_ effect: SpotEffect, from caller: SpotCaller?) -> Bool {
        guard let caller else { return takeFromPerson(effect) }
        take(effect, of: caller.spot.id, call: caller.call)
        return true
    }

    func take(_ effect: SpotEffect, of spot: String, call: OpenCall?) {
        guard let run = sheets[spot] else { return }
        if let call, run.isOutOfDate(call) { return }
        run.take(effect, of: call)
    }

    private func takeFromPerson(_ effect: SpotEffect) -> Bool {
        let open = openID.flatMap { sheets[$0] }
        switch effect {
        case .toast(let text):
            onReport("", .toast(text))
        case .select(let item):
            guard let open else { return false }
            open.show(selecting: item, need: .change)
        case .route(let move):
            guard let open else { return false }
            onReport(open.spot.id, .move(move))
        case .attachment:
            return false
        }
        return true
    }
}
