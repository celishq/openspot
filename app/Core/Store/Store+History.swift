import Foundation

extension Store {
    public var title: String {
        page?.spot.name ?? place.source?.name ?? "My spots"
    }

    public var back: [PageTrail<StoreStop>.Stop] { trail.back }
    public var forward: [PageTrail<StoreStop>.Stop] { trail.forward }
    public var visit: Int { trail.now.visit }

    var stop: StoreStop {
        StoreStop(place: place, spot: page?.id)
    }

    func arrive() {
        guard stop != trail.now.value else { return }
        trail.go(stop)
    }

    public func goBack() async {
        guard let last = trail.goBack() else { return }
        await go(to: last.value)
    }

    public func goForward() async {
        guard let next = trail.goForward() else { return }
        await go(to: next.value)
    }

    private func go(to stop: StoreStop) async {
        move(to: stop.place)
        if let spot = stop.spot { await load(spot) }
    }
}
