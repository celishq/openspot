import Foundation

public struct StoreStop: Hashable, Sendable {
    public let place: StorePlace
    public let spot: String?

    public init(place: StorePlace, spot: String?) {
        self.place = place
        self.spot = spot
    }
}
