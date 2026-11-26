import Foundation

public struct StoreStop: Hashable, Sendable {
    public let place: StorePlace
    public let spot: String?
    public let visit: Int

    public init(place: StorePlace, spot: String?, visit: Int) {
        self.place = place
        self.spot = spot
        self.visit = visit
    }

    func isSame(as other: StoreStop) -> Bool {
        place == other.place && spot == other.spot
    }
}
