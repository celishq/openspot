import Foundation

extension Store {
    public var title: String {
        page?.spot.name ?? place.source?.name ?? "My spots"
    }

    var stop: StoreStop {
        StoreStop(place: place, spot: page?.id)
    }

    func leave(_ from: StoreStop) {
        guard from != stop else { return }
        back.append(from)
        if !forward.isEmpty { forward = [] }
    }

    public func goBack() async {
        guard let last = back.popLast() else { return }
        forward.append(stop)
        await go(to: last)
    }

    public func goForward() async {
        guard let next = forward.popLast() else { return }
        back.append(stop)
        await go(to: next)
    }

    private func go(to stop: StoreStop) async {
        move(to: stop.place)
        if let spot = stop.spot { await load(spot) }
    }
}
