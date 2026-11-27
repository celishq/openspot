import Foundation

public struct SessionTrail: Equatable, Sendable {
    public static let limit = 20

    public typealias Place = SessionPlace

    public private(set) var places: [Place] = []
    public private(set) var index = 0

    public mutating func add(_ place: Place) {
        if let last = places.last, last.merges(with: place) { places.removeLast() }
        places.append(place)
        if places.count > Self.limit { places.removeFirst(places.count - Self.limit) }
        index = places.count
    }

    public mutating func back() -> Place? {
        guard index > 0 else { return nil }
        index -= 1
        return places[index]
    }

    public mutating func forward() -> Place? {
        guard index < places.count else { return nil }
        index += 1
        return index < places.count ? places[index] : nil
    }

    public var isWalking: Bool {
        index < places.count
    }

    public mutating func stopWalking() {
        index = places.count
    }
}
