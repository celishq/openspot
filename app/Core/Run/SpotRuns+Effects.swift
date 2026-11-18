import Foundation

extension SpotRuns {
    func take(_ effect: SpotEffect, from caller: SpotCaller?) -> Bool {
        guard let caller else { return takeFromPerson(effect) }
        guard let run = sheets[caller.spot.id] else { return true }
        let call = caller.call
        if let call, run.isOutOfDate(call) { return true }
        run.take(effect, of: call)
        return true
    }

    private func takeFromPerson(_ effect: SpotEffect) -> Bool {
        let open = openID.flatMap { sheets[$0] }
        switch effect {
        case .toast(let text):
            onReport("", .toast(text))
        case .select(let item):
            guard let open else { return false }
            open.read(selecting: item, need: .change)
        case .route(let move):
            guard let open else { return false }
            onReport(open.spot.id, .move(move))
        }
        return true
    }
}
